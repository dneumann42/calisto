local lgi = require("lgi")

-- lgi ships GTK3-era overrides for Gdk and Gtk that crash on GTK4
-- (gdk_threads_set_lock_functions, gtk_init_check, etc.).
-- Block them before lgi.require pulls in Gtk → Gdk.
package.preload["lgi.override.Gdk"] = function() return {} end
package.preload["lgi.override.Gtk"] = function() return {} end

local Gtk = lgi.require("Gtk", "4.0")
local LayerShell = lgi.require("Gtk4LayerShell", "1.0")

local BAR_HEIGHT = 40

local app = Gtk.Application.new("com.calisto.bar", 0)

-- held at module scope so lgi's GC doesn't unref it when on_activate returns
local window

app.on_activate = function()
    -- lgi does not register the window with GApplication's window tracking,
    -- so the app would quit the moment on_activate returns.  hold() keeps
    -- the main loop running for the lifetime of the process.
    app:hold()

    window = Gtk.Window.new()

    window:set_title("Calisto")
    window:set_size_request(-1, BAR_HEIGHT)
    window:set_decorated(false)
    window:set_can_focus(false)

    -- Dock this window as a layer-shell surface
    LayerShell.init_for_window(window)
    LayerShell.set_layer(window, LayerShell.Layer.TOP)
    LayerShell.set_keyboard_mode(window, LayerShell.KeyboardMode.NONE)

    -- Anchor to top edge, spanning full monitor width
    LayerShell.set_anchor(window, LayerShell.Edge.TOP,    true)
    LayerShell.set_anchor(window, LayerShell.Edge.LEFT,   true)
    LayerShell.set_anchor(window, LayerShell.Edge.RIGHT,  true)
    LayerShell.set_anchor(window, LayerShell.Edge.BOTTOM, false)

    -- Reserve screen space so windows don't render behind the bar
    LayerShell.set_exclusive_zone(window, BAR_HEIGHT)

    -- Flush to the top edge of the monitor
    LayerShell.set_margin(window, LayerShell.Edge.TOP,    0)
    LayerShell.set_margin(window, LayerShell.Edge.LEFT,   0)
    LayerShell.set_margin(window, LayerShell.Edge.RIGHT,  0)

    -- Sway (and other wlroots compositors) can match on this namespace
    -- e.g. in sway config: set_from_resource $calisto i3wm.calisto #000000
    LayerShell.set_namespace(window, "calisto")

    -- Placeholder content
    local box = Gtk.Box.new(Gtk.Orientation.HORIZONTAL, 0)
    box:set_valign(Gtk.Align.CENTER)
    box:set_margin_start(12)
    box:set_margin_end(12)
    box:append(Gtk.Label.new("Calisto"))

    window:set_child(box)
    window:present()
end

os.exit(app:run())
