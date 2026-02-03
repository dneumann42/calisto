local lgi  = require("lgi")
local Gtk  = lgi.require("Gtk", "4.0")

local UI = {}

function UI:bar(cfg)
   local bar = Gtk.Box.new(Gtk.Orientation.HORIZONTAL, 0)
   bar:set_valign(Gtk.Align.CENTER)

   local widgets = cfg.widgets or {}
   for i = 1, #widgets do
      bar:append(widgets[i])
   end
   
   return bar
end

return UI
