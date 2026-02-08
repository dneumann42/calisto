local lgi = require("lgi")
local Gtk = lgi.require("Gtk", "4.0")
local GLib = lgi.require("GLib", "2.0")
local Gio = lgi.require("Gio", "2.0") -- Need Gio for async subprocesses
local Widgets = {}
local Json = require("json")
local UI = require("ui")
local pp = require("pprint")

-- Asynchronous command runner using Gio.Subprocess
local function run_shell_command_async(command_args, callback)
    local process = Gio.Subprocess.new(command_args, Gio.SubprocessFlags.STDOUT_PIPE + Gio.SubprocessFlags.STDERR_PIPE)

    process:communicate_utf8_async(nil, nil, function(source, result)
        local ok, stdout, stderr = pcall(function()
            return source:communicate_utf8_finish(result)
        end)

        if not ok then
            print("ERROR: Command failed:", table.concat(command_args, " "), "-", stdout)
            callback(nil, "Failed to run command: " .. tostring(stdout))
            return
        end

        if process:get_successful() then
            callback(stdout, nil)
        else
            print("ERROR: Command failed:", table.concat(command_args, " "), "stderr:", stderr)
            callback(nil, "Command failed: " .. tostring(stderr))
        end
    end)
end

local function parse_sway_json(json_str)
    local decoded = Json.decode(json_str)
    local workspaces = {}

    for i = 1, #decoded do
        local ws = decoded[i]
        table.insert(workspaces, {
            name = ws.name,
            focused = ws.focused,
            urgent = ws.urgent,
            visible = ws.visible,
            num = tonumber(ws.num),
        })
    end
    table.sort(workspaces, function(a, b)
        return a.num < b.num
    end)
    return workspaces
end

local function apply_css(widget, css)
    if not css then
        return
    end
    local provider = Gtk.CssProvider.new()
    provider:load_from_string(css)
    widget:get_style_context():add_provider(provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)
end

local MONTHS = {
    "January",
    "February",
    "March",
    "April",
    "May",
    "June",
    "July",
    "August",
    "September",
    "October",
    "November",
    "December",
}

local function format_date(fmt)
    if fmt then
        return os.date(fmt)
    end
    local t = os.date("*t")
    local suf = (t.day >= 11 and t.day <= 13) and "th" or ({ [1] = "st", [2] = "nd", [3] = "rd" })[t.day % 10] or "th"
    local h12 = t.hour % 12
    if h12 == 0 then
        h12 = 12
    end
    return string.format(
        "%s %d%s, %d | %d:%02d%s",
        MONTHS[t.month],
        t.day,
        suf,
        t.year,
        h12,
        t.min,
        t.hour < 12 and "AM" or "PM"
    )
end

Widgets.bar = {}
function Widgets.bar:new(cfg)
    local gap = cfg.gap or 0
    local bar = Gtk.Box.new(Gtk.Orientation.HORIZONTAL, gap)
    bar:set_valign(Gtk.Align.CENTER)

    -- Always apply theme to ensure colors are updated
    UI:apply_theme(cfg.opacity, cfg.font, cfg.font_size)

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
    if not cfg.css then
        btn:set_margin_start(2)
    end
    btn.on_clicked = cfg.on_clicked or function()
        print("Button clicked")
    end
    apply_css(btn, cfg.css)
    return btn
end

Widgets.clock = {}
function Widgets.clock:new(cfg)
    local clock = Gtk.Label.new(format_date(cfg.format))
    if not cfg.css then
        clock:set_margin_end(12)
    end

    GLib.timeout_add(GLib.PRIORITY_DEFAULT, 1000, function()
        clock:set_text(format_date(cfg.format))
        if cfg.tick and not cfg.tick() then
            return false
        end
        return true
    end)
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

Widgets.media = {}
function Widgets.media:new(cfg)
   local media_script = os.getenv("HOME") .. "/.alatar/scripts/media.sh"
   local media_box = Gtk.Box.new(Gtk.Orientation.HORIZONTAL, 0)
   media_box:set_valign(Gtk.Align.CENTER)
   media_box:set_spacing(0)

   -- Create buttons with GTK icons
   local prev_btn = Gtk.Button.new()
   local prev_icon = Gtk.Image.new_from_icon_name("media-skip-backward-symbolic")
   prev_btn:set_child(prev_icon)

   local toggle_btn = Gtk.Button.new()
   local toggle_icon = Gtk.Image.new_from_icon_name("media-playback-start-symbolic")
   toggle_btn:set_child(toggle_icon)

   local next_btn = Gtk.Button.new()
   local next_icon = Gtk.Image.new_from_icon_name("media-skip-forward-symbolic")
   next_btn:set_child(next_icon)

   -- Create scrollable label container
   local info_label = Gtk.Label.new("No track")
   info_label:set_ellipsize(3) -- PANGO_ELLIPSIZE_END
   info_label:set_max_width_chars(30)
   info_label:set_xalign(0) -- Left align

   -- Wrap label in an event box for the pill styling
   local label_box = Gtk.Box.new(Gtk.Orientation.HORIZONTAL, 0)
   label_box:append(info_label)
   label_box:set_size_request(200, -1) -- Max width 200px

   -- Apply CSS classes
   prev_btn:add_css_class("media-pill-left")
   toggle_btn:add_css_class("media-pill-middle")
   next_btn:add_css_class("media-pill-middle")
   label_box:add_css_class("media-pill-right")

   -- Apply themed CSS if provided in config
   if cfg and cfg.css then
      apply_css(media_box, cfg.css)
   end

   -- Button actions
   prev_btn.on_clicked = function()
      run_shell_command_async({media_script, "prev"}, function() end)
   end

   toggle_btn.on_clicked = function()
      run_shell_command_async({media_script, "toggle"}, function() end)
   end

   next_btn.on_clicked = function()
      run_shell_command_async({media_script, "next"}, function() end)
   end

   -- Marquee scrolling state
   local full_text = "No track"
   local scroll_offset = 0
   local scroll_timer = nil

   -- Update function
   local function update_media()
      -- Get full status including class
      run_shell_command_async({media_script, "status"}, function(output, err)
         if not err and output then
            local ok, data = pcall(Json.decode, output)
            if ok then
               -- Update icon based on playback state from class
               if data.class then
                  local state = nil
                  for _, cls in ipairs(data.class) do
                     if cls == "playing" then
                        state = "playing"
                        break
                     elseif cls == "paused" then
                        state = "paused"
                        break
                     end
                  end

                  if state == "playing" then
                     toggle_icon:set_from_icon_name("media-playback-pause-symbolic")
                  else
                     toggle_icon:set_from_icon_name("media-playback-start-symbolic")
                  end
               end
            end
         end
      end)

      -- Get track info
      run_shell_command_async({media_script, "track"}, function(output, err)
         if not err and output then
            local ok, data = pcall(Json.decode, output)
            if ok and data.text then
               -- Clean text: remove leading/trailing whitespace and non-printable chars
               -- Remove common icon byte sequences (UTF-8 for Private Use Area)
               full_text = data.text:gsub("[\239][\140-\191][\128-\191]", "")  -- Remove U+E000-U+EFFF range
                                         :gsub("[\239][\184-\191][\128-\191]", "")  -- Remove U+F800-U+FFFF range
                                         :gsub("^%s+", ""):gsub("%s+$", "")  -- Trim whitespace
               if full_text == "" then
                  full_text = "No track"
               end
               scroll_offset = 0

               -- If text is too long, start scrolling
               if #full_text > 30 then
                  if scroll_timer then
                     GLib.source_remove(scroll_timer)
                  end
                  scroll_timer = GLib.timeout_add(GLib.PRIORITY_DEFAULT, 200, function()
                     scroll_offset = scroll_offset + 1
                     if scroll_offset > #full_text then
                        scroll_offset = 0
                     end
                     local visible_text = string.sub(full_text .. "   " .. full_text, scroll_offset + 1, scroll_offset + 30)
                     info_label:set_text(visible_text)
                     return true
                  end)
               else
                  if scroll_timer then
                     GLib.source_remove(scroll_timer)
                     scroll_timer = nil
                  end
                  info_label:set_text(full_text)
               end
            end
         end
      end)

      return true -- Continue timer
   end

   -- Initial update and setup timer
   update_media()
   GLib.timeout_add(GLib.PRIORITY_DEFAULT, 2000, update_media)

   -- Add widgets to box
   media_box:append(prev_btn)
   media_box:append(toggle_btn)
   media_box:append(next_btn)
   media_box:append(label_box)

   return media_box
end

Widgets.workspaces = {}
function Widgets.workspaces:new(cfg)
    local gap = (cfg and cfg.gap) or 2
    local workspace_box = Gtk.Box.new(Gtk.Orientation.HORIZONTAL, 0)
    workspace_box:set_valign(Gtk.Align.CENTER)
    workspace_box:set_spacing(gap) -- Configurable spacing between workspace buttons

    -- get_sway_workspaces now takes a callback
    local get_sway_workspaces = function(callback)
        run_shell_command_async({ "swaymsg", "-t", "get_workspaces" }, function(output, err)
            if err then
                print("ERROR: Failed to get sway workspaces:", err)
                callback({}, err)
                return
            end
            local parsed_workspaces = parse_sway_json(output)
            callback(parsed_workspaces, nil)
        end)
    end

    local current_buttons = {} -- Map from workspace number to Gtk.Button
    local last_states = {} -- Map from workspace number to its last known state {focused, urgent, urgent, visible}

    local function process_workspaces(workspaces)
        local new_button_order = {} -- To store buttons in the order they should appear
        local new_num_to_ws = {} -- Map new workspace numbers to their data for easy lookup

        for _, ws in ipairs(workspaces) do
            new_num_to_ws[ws.num] = ws
        end

        -- Process existing and new workspaces
        for _, ws in ipairs(workspaces) do
            local btn = current_buttons[ws.num]
            local is_new_button = false

            if not btn then
                -- Create new button if it doesn't exist
                btn = Gtk.Button.new_with_label(ws.name)
                btn:add_css_class("workspace") -- Add base class
                btn.on_clicked = function()
                    run_shell_command_async({ "swaymsg", "workspace", ws.name }, function(output, err)
                        if err then
                            print("ERROR: Failed to switch workspace:", err)
                        end
                    end)
                end
                workspace_box:append(btn)
                current_buttons[ws.num] = btn
                is_new_button = true
            else
                -- Update label if name changed
                if btn:get_label() ~= ws.name then
                    btn:set_label(ws.name)
                end
            end
            table.insert(new_button_order, btn)

            -- Update CSS classes if state changed or it's a new button
            local last_state = last_states[ws.num]
            local state_changed = not last_state
                or last_state.focused ~= ws.focused
                or last_state.urgent ~= ws.urgent
                or last_state.visible ~= ws.visible

            if is_new_button or state_changed then
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
            last_states[ws.num] = { focused = ws.focused, urgent = ws.urgent, visible = ws.visible }
        end

        -- Remove buttons for workspaces that no longer exist
        for num, btn in pairs(current_buttons) do
            if not new_num_to_ws[num] then
                workspace_box:remove(btn)
                current_buttons[num] = nil
                last_states[num] = nil
            end
        end

        for i, btn in ipairs(new_button_order) do
            if i == 1 then
                workspace_box:reorder_child_after(btn, nil) -- Place first button at the beginning
            else
                workspace_box:reorder_child_after(btn, new_button_order[i - 1])
            end
        end
    end

    -- Debounced update: only update after events stop for 100ms
    local update_timer = nil
    local function update_workspaces_ui_from_sway()
        get_sway_workspaces(function(workspaces, err)
            if not err then
                process_workspaces(workspaces)
            else
                print("ERROR: Failed to get workspaces:", err)
            end
        end)
        return true -- Continue GLib.timeout_add
    end

    local function schedule_update()
        -- Cancel existing timer if any
        if update_timer then
            GLib.source_remove(update_timer)
        end
        -- Schedule update after 100ms of no events
        update_timer = GLib.timeout_add(GLib.PRIORITY_DEFAULT, 100, function()
            update_workspaces_ui_from_sway()
            update_timer = nil
            return false -- Don't repeat
        end)
    end

    update_workspaces_ui_from_sway()

    local function subscribe_workspaces()
        local cmd = { "sh", "-c", "stdbuf -oL swaymsg -m -t subscribe '[\"workspace\"]' | jq -c" }
        local process = Gio.Subprocess.new(cmd, Gio.SubprocessFlags.STDOUT_PIPE + Gio.SubprocessFlags.STDERR_PIPE)
        local stdout_stream = Gio.DataInputStream.new(process:get_stdout_pipe())
        local stderr_stream = Gio.DataInputStream.new(process:get_stderr_pipe())

        local function restart_subscription(delay)
            GLib.timeout_add(GLib.PRIORITY_DEFAULT, delay, function()
                subscribe_workspaces()
                return false
            end)
        end

        -- Asynchronously wait for the process to exit
        process:wait_async(nil, nil, function(source_object, res)
            source_object:wait_finish(res)
            -- Read any remaining stderr output
            stderr_stream:read_upto_end_async(GLib.PRIORITY_DEFAULT, nil, function(source_object_err, res_err)
                local stderr_bytes = source_object_err:read_upto_end_finish(res_err)
                if stderr_bytes then
                    local stderr_output = stderr_bytes:get_data()
                    if #stderr_output > 0 then
                        print("ERROR: Swaymsg stderr:", stderr_output)
                    end
                end
                restart_subscription(2000)
            end)
        end)

        local cancellable = Gio.Cancellable.new()

        local function read_next_line()
            stdout_stream:read_line_async(GLib.PRIORITY_DEFAULT, cancellable, function(source_object, res)
                local line, _length, err = source_object:read_line_finish(res)
                if line then
                    local ok, event = pcall(Json.decode, line)
                    if ok and event.change then
                        schedule_update()
                    elseif not ok then
                        print("ERROR: Failed to parse workspace event:", event)
                    end
                    read_next_line()
                elseif err then
                    print("ERROR: Failed reading from swaymsg pipe:", err)
                end
            end)
        end
        read_next_line()
    end

    subscribe_workspaces()

    -- Apply CSS if provided
    if cfg and cfg.css then
        apply_css(workspace_box, cfg.css)
    end

    print("Workspaces widget created, returning workspace_box")
    return workspace_box
end

return Widgets
