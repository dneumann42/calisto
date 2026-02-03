local lgi  = require("lgi")
local Gtk  = lgi.require("Gtk", "4.0")
local GLib = lgi.require("GLib", "2.0")
local Widgets = import("widgets")
local UI = import("ui")
local Theme = import("theme")

local stopped = false

-- interpolate {theme_key} placeholders from the active palette
local function css(str) return str:gsub("{([%w_]+)}", UI.theme) end

local bar = Widgets.bar:new {
   opacity = 0.5,
   widgets = {
      Widgets.button:new {
         label = "#",
         css = css(Theme.Button),
         on_clicked = function()
            print("HERE!")
         end
      },
      Widgets.workspaces:new {},
      Widgets.hspacer:new(),
      Widgets.clock:new {
	 css = css(Theme.Clock),
	 tick = function()
	    return not stopped
	 end
      }
   }
}

return bar, function() stopped = true end
