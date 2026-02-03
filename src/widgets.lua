local lgi  = require("lgi")
local Gtk  = lgi.require("Gtk", "4.0")
local GLib = lgi.require("GLib", "2.0")
local Gio = lgi.require("Gio", "2.0") -- Need Gio for async subprocesses
local Widgets = {}
local Json = require("json")
local UI = require("ui")
local pp = require("pprint")

-- Remove synchronous command runner
-- local function run_shell_command_sync(command)
--     local handle = io.popen(command, "r")
--     if not handle then return nil, "Failed to open pipe" end
--     local output = handle:read("*a")
--     local status = handle:close()
--     if not status then return output, "Command exited with error" end
--     return output, nil
-- end

-- Asynchronous command runner
local function run_shell_command_async(command_args, callback)
    GLib.spawn_async_with_pipes(
        nil, -- working directory
        command_args,
        nil, -- envp
        GLib.SpawnFlags.SEARCH_PATH,
        nil, -- child setup
        nil, -- user data
        function(pid, stdout_fd, stderr_fd)
            -- We don't need pid, stdout_fd, stderr_fd here,
            -- as the actual reading will happen in the callback.
            -- This function just starts the process.
        end,
        function(pid, status, stdout_data, stderr_data)
            local stdout_str = ""
            if stdout_data then
                stdout_str = stdout_data:get_data() -- GLib.Bytes to string
            end
            local stderr_str = ""
            if stderr_data then
                stderr_str = stderr_data:get_data() -- GLib.Bytes to string
            end

            print(string.format("run_shell_command_async finished for: %s", table.concat(command_args, " ")))
            print("  Stdout:", stdout_str)
            print("  Stderr:", stderr_str)

            print("Invoking run_shell_command_async callback...")
            if status == 0 then
                callback(stdout_str, nil)
            else
                callback(nil, "Command exited with status " .. status .. ": " .. stderr_str)
            end
            GLib.spawn_close_pid(pid)
        end,
        nil -- user_data for the callback
    )
end

local function parse_sway_json(json_str)
   local decoded = Json.decode(json_str)
   local workspaces = {}

   for i = 1, #decoded do
      local ws = decoded[i]
      table.insert(
	 workspaces,
	 {
	    name = ws.name,
	    focused = ws.focused,
	    urgent = ws.urgent,
	    visible = ws.visible,
	    num = tonumber(ws.num),
	 }
      )
   end
   table.sort(workspaces, function(a, b) return a.num < b.num end)
   return workspaces
end

local function apply_css(widget, css)
   if not css then return end
   local provider = Gtk.CssProvider.new()
   provider:load_from_string(css)
   widget:get_style_context():add_provider(provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)
end

local MONTHS = {
   "January","February","March","April","May","June",
   "July","August","September","October","November","December",
}

local function format_date(fmt)
   if fmt then return os.date(fmt) end
   local t   = os.date("*t")
   local suf = (t.day >= 11 and t.day <= 13) and "th"
           or  ({ [1] = "st", [2] = "nd", [3] = "rd" })[t.day % 10]
           or  "th"
   local h12 = t.hour % 12;  if h12 == 0 then h12 = 12 end
   return string.format("%s %d%s, %d | %d:%02d%s",
      MONTHS[t.month], t.day, suf, t.year,
      h12, t.min, t.hour < 12 and "AM" or "PM")
end

Widgets.bar = {}
function Widgets.bar:new(cfg)
   local bar = Gtk.Box.new(Gtk.Orientation.HORIZONTAL, 0)
   bar:set_valign(Gtk.Align.CENTER)

   if cfg.opacity then
      UI:apply_theme(cfg.opacity)
   end

   local widgets = cfg.widgets or {}
   for i = 1, #widgets do
      bar:append(widgets[i])
   end

   return bar
end

Widgets.button = {}
function Widgets.button:new(cfg)
   local label = cfg.label or "Button"
   local btn = Gtk.Button.new_with_label(label)
   if not cfg.css then btn:set_margin_start(2) end
   btn.on_clicked = cfg.on_clicked or function()
      print("Button clicked")
   end
   apply_css(btn, cfg.css)
   return btn
end

Widgets.clock = {}
function Widgets.clock:new(cfg)
   local clock = Gtk.Label.new(format_date(cfg.format))
   if not cfg.css then clock:set_margin_end(12) end

   GLib.timeout_add(
      GLib.PRIORITY_DEFAULT,
      1000,
      function()
	 clock:set_text(format_date(cfg.format))
	 if cfg.tick and not cfg.tick() then
	    return false
	 end
	 return true
      end
   )
   apply_css(clock, cfg.css)
   return clock
end

Widgets.hspacer = {}
function Widgets.hspacer:new(cfg)
   local spacer = Gtk.Box.new(Gtk.Orientation.HORIZONTAL, 0)
   spacer:set_hexpand(true)
   apply_css(spacer, (cfg or {}).css or "")
   return spacer
end

Widgets.workspaces = {}
function Widgets.workspaces:new(cfg)
   print("Widgets.workspaces:new called")
   local workspace_box = Gtk.Box.new(Gtk.Orientation.HORIZONTAL, 0)
   workspace_box:set_valign(Gtk.Align.CENTER)

   -- get_sway_workspaces now takes a callback
   local get_sway_workspaces = function(callback)
       print("Calling swaymsg -t get_workspaces asynchronously")
       run_shell_command_async({"swaymsg", "-t", "get_workspaces"}, function(output, err)
           if err then
               print("Error getting sway workspaces (async):", err)
               callback({}, err)
               return
           end
           print("Swaymsg get_workspaces output received (async):", output)
           local parsed_workspaces = parse_sway_json(output)
           print("Parsed workspaces:", pp.format(parsed_workspaces))
           callback(parsed_workspaces, nil)
       end)
   end

   local current_buttons = {} -- Map from workspace number to Gtk.Button
   local last_states = {}     -- Map from workspace number to its last known state {focused, urgent, urgent, visible}

   local function process_workspaces(workspaces)
       print("Processing workspaces:", pp.format(workspaces))
       local new_button_order = {} -- To store buttons in the order they should appear
       local new_num_to_ws = {}    -- Map new workspace numbers to their data for easy lookup

       for _, ws in ipairs(workspaces) do
           new_num_to_ws[ws.num] = ws
       end

       -- Process existing and new workspaces
       for _, ws in ipairs(workspaces) do
           local btn = current_buttons[ws.num]
           local is_new_button = false

           if not btn then
               -- Create new button if it doesn't exist
               print("Creating button for workspace:", ws.name)
               btn = Gtk.Button.new_with_label(ws.name)
               btn:add_css_class("workspace") -- Add base class
               btn.on_clicked = function()
		  print("Workspace button clicked:", ws.name)
		  run_shell_command_async({"swaymsg", "workspace", ws.name}, function(output, err)
		      if err then print("Error switching workspace:", err) end
		  end)
               end
               workspace_box:append(btn)
               current_buttons[ws.num] = btn
               is_new_button = true
           else
               -- Update label if name changed
               if btn:get_label() ~= ws.name then
                   print("Updating label for workspace:", ws.name)
                   btn:set_label(ws.name)
               end
           end
           table.insert(new_button_order, btn)

           -- Update CSS classes if state changed or it's a new button
           local last_state = last_states[ws.num]
           local state_changed = not last_state or
                                 last_state.focused ~= ws.focused or
                                 last_state.urgent ~= ws.urgent or
                                 last_state.visible ~= ws.visible

           if is_new_button or state_changed then
               print("Updating CSS for workspace:", ws.name, "Focused:", ws.focused, "Urgent:", ws.urgent, "Visible:", ws.visible)
               -- Remove all state-related classes first
               btn:remove_css_class("focused")
               btn:remove_css_class("urgent")
               btn:remove_css_class("occupied")

               -- Add new state-related classes
               if ws.focused then
                   btn:add_css_class("focused")
               elseif ws.urgent then
                   btn:add_css_class("urgent")
               elseif ws.visible then
                   btn:add_css_class("occupied")
               end
           end
           last_states[ws.num] = {focused = ws.focused, urgent = ws.urgent, visible = ws.visible}
       end

       -- Remove buttons for workspaces that no longer exist
       for num, btn in pairs(current_buttons) do
           if not new_num_to_ws[num] then
               print("Removing button for workspace num:", num)
               workspace_box:remove(btn)
               current_buttons[num] = nil
               last_states[num] = nil
           end
       end

       for i, btn in ipairs(new_button_order) do
           if i == 1 then
               workspace_box:reorder_child_after(btn, nil) -- Place first button at the beginning
           else
               workspace_box:reorder_child_after(btn, new_button_order[i-1])
           end
       end
       print("Finished processing workspaces.")
   end

   local function update_workspaces_ui_from_sway()
      print("update_workspaces_ui_from_sway called")
      get_sway_workspaces(function(workspaces, err)
         if not err then
            process_workspaces(workspaces)
         else
            print("Failed to get workspaces for UI update:", err)
         end
      end)
      return true -- Continue GLib.timeout_add
   end

   print("Calling initial update_workspaces_ui_from_sway()")
   update_workspaces_ui_from_sway()

   local function subscribe_workspaces()
      print("subscribe_workspaces called - starting swaymsg subscribe process")
      local cmd = {"swaymsg", "-t", "subscribe", '["workspace"]'}
      local process = Gio.Subprocess.new(cmd, Gio.SubprocessFlags.STDOUT_PIPE + Gio.SubprocessFlags.STDERR_PIPE)
      local stdout_stream = Gio.DataInputStream.new(process:get_stdout_pipe())
      local stderr_stream = Gio.DataInputStream.new(process:get_stderr_pipe()) -- Get stderr stream

      local function restart_subscription(delay)
         print(string.format("Swaymsg subscribe process finished. Restarting in %dms...", delay))
         GLib.timeout_add(GLib.PRIORITY_DEFAULT, delay, function()
            subscribe_workspaces()
            return false -- Do not repeat this timeout
         end)
      end

      -- Asynchronously wait for the process to exit
      process:wait_async(nil, nil, function(source_object, res)
         local success, err_msg, exit_status, term_signal = source_object:wait_finish(res)
         print(string.format("Swaymsg subscribe process finished. Success: %s, Exit Status: %s, Signal: %s, Error Message: %s",
                             tostring(success), tostring(exit_status), tostring(term_signal), tostring(err_msg)))

         -- Read any remaining stderr output (asynchronously)
         stderr_stream:read_upto_end_async(GLib.PRIORITY_DEFAULT, nil, function(source_object_err, res_err)
            local stderr_bytes, err_read = source_object_err:read_upto_end_finish(res_err)
            if stderr_bytes then
               local stderr_output = stderr_bytes:get_data()
               if #stderr_output > 0 then
                  print("Swaymsg stderr (on exit):", stderr_output)
               end
            elseif err_read then
               print("Error reading stderr on process exit:", err_read)
            end
            restart_subscription(2000) -- Restart after getting stderr
         end)
      end)

      local function read_next_line()
         stdout_stream:read_line_async(GLib.PRIORITY_DEFAULT, nil, function(source_object, res)
            local line, length, err = source_object:read_line_finish(res)
            if line then
               print("Swaymsg subscribe event received:", line)
               local ok, event = pcall(Json.decode, line)
               if ok and (event.change == "focus" or event.change == "init" or event.change == "empty" or event.change == "rename" or event.change == "urgent" or event.change == "close") then
                  print("Relevant workspace event, triggering UI update.")
                  update_workspaces_ui_from_sway()
               end
               read_next_line() -- Continue reading
            elseif err then
               print("Error reading from swaymsg subscribe pipe (mid-stream):", err)
               -- The process:wait_async will handle the restart if the process truly exited.
               -- Otherwise, this indicates a stream error which might recover or lead to process exit.
            else
               -- End of stream (process likely exited cleanly or crashed)
               print("Swaymsg stdout stream ended. Waiting for process exit details...")
               -- The process:wait_async will handle the restart logic here.
            end
         end)
      end
      read_next_line()
   end
   
   subscribe_workspaces() -- Start the subscription

   apply_css(workspace_box, (cfg or {}).css or "")
   return workspace_box
end

return Widgets
