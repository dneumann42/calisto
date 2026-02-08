-- Set up file logging
local log_file = io.open("/tmp/calisto.log", "w")
local original_print = print
_G.print = function(...)
   local args = {...}
   local parts = {}
   for i = 1, #args do
      parts[i] = tostring(args[i])
   end
   local msg = table.concat(parts, "\t")
   local timestamp = os.date("%H:%M:%S")
   local line = string.format("[%s] %s\n", timestamp, msg)
   if log_file then
      log_file:write(line)
      log_file:flush()
   end
   original_print(...)
end

local lgi = require("lgi")

-- lgi ships GTK3-era overrides for Gdk and Gtk that crash on GTK4
-- (gdk_threads_set_lock_functions, gtk_init_check, etc.).
-- Block them before lgi.require pulls in Gtk → Gdk.
package.preload["lgi.override.Gdk"] = function() return {} end
package.preload["lgi.override.Gtk"] = function() return {} end

local Gtk        = lgi.require("Gtk", "4.0")
local GLib       = lgi.require("GLib", "2.0")
local Gio        = lgi.require("Gio", "2.0")
local LayerShell = lgi.require("Gtk4LayerShell", "1.0")

local BAR_HEIGHT = 40

-- Directory this script lives in — lets us find gui.lua regardless of cwd
local SCRIPT_DIR = (arg[0] or ""):match("(.+)/") or "."

-- Support development mode: if CALISTO_DEV_DIR is set, use it for watching/loading
-- This allows `nix run .` to hotload from the source directory
local DEV_DIR = os.getenv("CALISTO_DEV_DIR")
local WATCH_DIR = DEV_DIR or SCRIPT_DIR
local GUI_PATH = WATCH_DIR .. "/src/gui.lua"

if DEV_DIR then
   print("[calisto] Development mode: watching " .. DEV_DIR)
end

-------------------------------------------------------------------------------
-- import(name)  —  like require, but never caches.  Always reads and evals.
-- Dot separators map to directories:  import("foo.bar") → foo/bar.lua
-- Paths are resolved relative to WATCH_DIR (dev dir if set, else script dir).
-- The chunk name is set to "@<path>" so stack traces point to the file.
-------------------------------------------------------------------------------
function import(name)                                          -- intentionally global
    local path = WATCH_DIR .. "/src/" .. name:gsub("%.", "/") .. ".lua"
    local f    = io.open(path, "r")
    if not f then error("import: cannot open '" .. path .. "'", 2) end
    local src  = f:read("a"); f:close()
    local chunk, err = load(src, "@" .. path)
    if not chunk then error("import: " .. err, 2) end
    return chunk()
end

local app        = Gtk.Application.new("com.calisto.bar", 0)
local window
local gui_cleanup

local function reload()
    if gui_cleanup then gui_cleanup(); gui_cleanup = nil end

    local ok, widget, clean = pcall(dofile, GUI_PATH)
    if not ok then
        print("[calisto] " .. tostring(widget))   -- widget holds the error msg
        return
    end

    gui_cleanup = clean
    if window then window:set_child(widget) end
end

local function mtime(path)
    local info = Gio.File.new_for_path(path):query_info("time::modified", 0, nil)
    return info and info:get_modification_time().tv_sec or 0
end

-- collect all .lua files in src/ at startup
local function scan_src()
    local files = {}
    local dir  = Gio.File.new_for_path(WATCH_DIR .. "/src")
    local iter = dir:enumerate_children("standard::name,standard::type", 0, nil)
    local info = iter:next_file(nil)
    while info do
        local name = info:get_name()
        if name:match("%.lua$") then
            files[#files + 1] = WATCH_DIR .. "/src/" .. name
        end
        info = iter:next_file(nil)
    end
    return files
end
local WATCHED = scan_src()

local function start_poller()
    local cache = {}
    for _, path in ipairs(WATCHED) do cache[path] = mtime(path) end

    GLib.timeout_add(GLib.PRIORITY_DEFAULT, 250, function()
        for _, path in ipairs(WATCHED) do
            local current = mtime(path)
            if current ~= cache[path] then
                cache[path] = current
                reload()
                break                          -- one reload per tick is enough
            end
        end
        return true
    end)
end

app.on_activate = function()
    app:hold()

    Gtk.Settings.get_default().gtk_application_prefer_dark_theme = true

    window = Gtk.Window.new()
    window:set_title("Calisto")
    window:set_size_request(-1, BAR_HEIGHT)
    window:set_decorated(false)
    window:set_can_focus(false)

    -- layer-shell: dock as a top-edge panel
    LayerShell.init_for_window(window)
    LayerShell.set_layer(window, LayerShell.Layer.TOP)
    LayerShell.set_keyboard_mode(window, LayerShell.KeyboardMode.NONE)

    LayerShell.set_anchor(window, LayerShell.Edge.TOP,    true)
    LayerShell.set_anchor(window, LayerShell.Edge.LEFT,   true)
    LayerShell.set_anchor(window, LayerShell.Edge.RIGHT,  true)
    LayerShell.set_anchor(window, LayerShell.Edge.BOTTOM, false)

    LayerShell.set_exclusive_zone(window, BAR_HEIGHT)

    LayerShell.set_margin(window, LayerShell.Edge.TOP,    0)
    LayerShell.set_margin(window, LayerShell.Edge.LEFT,   0)
    LayerShell.set_margin(window, LayerShell.Edge.RIGHT,  0)

    LayerShell.set_namespace(window, "calisto")

    reload()
    start_poller()

    window:present()
end

os.exit(app:run())
