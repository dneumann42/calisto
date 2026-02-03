local lgi  = require("lgi")
local Gtk  = lgi.require("Gtk", "4.0")
local GLib = lgi.require("GLib", "2.0")
local Widgets = import("widgets")
local UI = import("ui")

local stopped = false

local bar = UI:bar {
   widgets = {
      Widgets.button:new {
	 label = "Click Me!",
	 on_clicked = function()
	    print("HERE!")
	 end
      },
      Widgets.hspacer:new(),
      Widgets.clock:new {
	 tick = function()
	    return not stopped
	 end
      }
   }
}

return bar, function() stopped = true end
