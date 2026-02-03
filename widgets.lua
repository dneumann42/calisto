local lgi  = require("lgi")
local Gtk  = lgi.require("Gtk", "4.0")
local GLib = lgi.require("GLib", "2.0")
local Widgets = {}
local Json = require("json")
local UI = require("ui")
local pp = require("pprint")

local function run_shell_command_sync(command)
    local handle = io.popen(command, "r")
    if not handle then return nil, "Failed to open pipe" end
    local output = handle:read("*a")
    local status = handle:close()
    if not status then return output, "Command exited with error" end
    return output, nil
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
   local workspace_box = Gtk.Box.new(Gtk.Orientation.HORIZONTAL, 0)
   workspace_box:set_valign(Gtk.Align.CENTER)

   local get_sway_workspaces = function()
       local output, err = run_shell_command_sync("swaymsg -t get_workspaces")
       if err then
           print("Error getting sway workspaces:", err)
           return {}
       end
       return parse_sway_json(output)
   end

   local current_buttons = {} -- Map from workspace number to Gtk.Button
   local last_states = {}     -- Map from workspace number to its last known state {focused, urgent, visible}

   local function update_workspaces()
       local workspaces = get_sway_workspaces()
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
               btn = Gtk.Button.new_with_label(ws.name)
               btn:add_css_class("workspace") -- Add base class
               btn.on_clicked = function()
                   run_shell_command_sync(string.format("swaymsg workspace %s", ws.name))
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
           local state_changed = not last_state or
                                 last_state.focused ~= ws.focused or
                                 last_state.urgent ~= ws.urgent or
                                 last_state.visible ~= ws.visible

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
           last_states[ws.num] = {focused = ws.focused, urgent = ws.urgent, visible = ws.visible}
       end

       -- Remove buttons for workspaces that no longer exist
       for num, btn in pairs(current_buttons) do
           if not new_num_to_ws[num] then
               workspace_box:remove(btn)
               current_buttons[num] = nil
               last_states[num] = nil
           end
       end

       -- Reorder buttons in the box to match the sorted workspaces
       local children = workspace_box:get_children()
       local current_visual_order = {}
       for _, child in ipairs(children) do
           table.insert(current_visual_order, child)
       end

       local needs_reorder = false
       if #current_visual_order ~= #new_button_order then
           needs_reorder = true
       else
           for i, btn in ipairs(current_visual_order) do
               if btn ~= new_button_order[i] then
                   needs_reorder = true
                   break
               end
           end
       end

       if needs_reorder then
           for i, btn in ipairs(new_button_order) do
               if i == 1 then
                   workspace_box:reorder_child_after(btn, nil) -- Place first button at the beginning
               else
                   workspace_box:reorder_child_after(btn, new_button_order[i-1])
               end
           end
       end
       
       return true
   end

   -- Initial update
   update_workspaces()

   -- Update every 500ms
   GLib.timeout_add(GLib.PRIORITY_DEFAULT, 500, update_workspaces)

   apply_css(workspace_box, (cfg or {}).css or "") -- Apply any additional CSS to the box itself
   return workspace_box
end

return Widgets
