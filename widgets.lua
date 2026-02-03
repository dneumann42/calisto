local lgi  = require("lgi")
local Gtk  = lgi.require("Gtk", "4.0")
local GLib = lgi.require("GLib", "2.0")
local Widgets = {}

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

Widgets.button = {}
function Widgets.button:new(cfg)
   local label = cfg.label or "Button"
   local btn = Gtk.Button.new_with_label(label)
   btn:set_margin_start(2)
   btn.on_clicked = cfg.on_clicked or function()
      print("Button clicked")
   end
   return btn
end

Widgets.clock = {}
function Widgets.clock:new(cfg)
   local clock = Gtk.Label.new(format_date(cfg.format))
   clock:set_margin_end(12)

   local stopped = false
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
   return clock
end

Widgets.hspacer = {}
function Widgets.hspacer:new(cfg)
   local spacer = Gtk.Box.new(Gtk.Orientation.HORIZONTAL, 0)
   spacer:set_hexpand(true)
   return spacer
end

return Widgets
