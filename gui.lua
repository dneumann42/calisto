local lgi  = require("lgi")
local Gtk  = lgi.require("Gtk", "4.0")
local GLib = lgi.require("GLib", "2.0")
local Widgets = import("widgets")
local UI = import("ui")

local stopped = false

-- interpolate {theme_key} placeholders from the active palette
local function css(str) return str:gsub("{([%w_]+)}", UI.theme) end

local bar = UI:bar {
   widgets = {
      Widgets.button:new {
	 label = "Click Me!",
	 css = css [[
	    button {
	       background-image: linear-gradient(135deg, {accent}, {surface});
	       color: {fg};
	       border: 1px solid {accent};
	       border-radius: 12px;
	       padding: 0px 8px;
	       margin: 0px 2px;
	    }
	    button:hover {
	       background-image: linear-gradient(135deg, {surface_alt}, {surface});
	       border-color: {fg_muted};
	    }
	    button:active {
	       background-image: linear-gradient(135deg, {surface}, {accent});
	    }
	 ]],
	 on_clicked = function()
	    print("HERE!")
	 end
      },
      Widgets.hspacer:new(),
      Widgets.clock:new {
	 css = css [[
	    label {
	       background-image: linear-gradient(135deg, {highlight_alt}, {surface});
	       color: {fg};
	       border: 1px solid {accent_alt};
	       border-radius: 12px;
	       padding: 0px 8px;
	       margin: 0px 2px;
	    }
	 ]],
	 tick = function()
	    return not stopped
	 end
      }
   }
}

return bar, function() stopped = true end
