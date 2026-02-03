local lgi  = require("lgi")
local Gtk  = lgi.require("Gtk", "4.0")
local GLib = lgi.require("GLib", "2.0")
local Widgets = {}

local UI = require("ui")

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
end

return Widgets
