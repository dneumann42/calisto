local lgi  = require("lgi")
local Gtk  = lgi.require("Gtk", "4.0")
local GLib = lgi.require("GLib", "2.0")
local Gio  = lgi.require("Gio", "2.0")
local Widgets = import("widgets")
local UI = import("ui")
local default_theme = import("theme")

-- interpolate {theme_key} placeholders from the active palette
local function css(str)
   if not str then return "" end
   return str:gsub("{([%w_]+)}", UI.theme)
end

-- Theme loading and merging
local current_theme = {}

local function load_theme()
   local config_dir = os.getenv("HOME") .. "/.config/calisto"
   local user_styles_path = config_dir .. "/styles.lua"

   -- Load default theme from file
   -- Use CALISTO_DEV_DIR if set (for nix run . with hotloading), else try PWD
   local dev_dir = os.getenv("CALISTO_DEV_DIR")
   local default_theme_path
   if dev_dir then
      default_theme_path = dev_dir .. "/src/theme.lua"
   else
      local cwd = os.getenv("PWD") or io.popen("pwd"):read("*l")
      default_theme_path = cwd .. "/src/theme.lua"
   end

   -- Check if file exists
   local test_file = io.open(default_theme_path, "r")
   if not test_file then
      -- Fall back to using the imported theme
      default_theme_path = nil
   else
      test_file:close()
   end

   local merged = {}

   -- Load default theme from file if available
   if default_theme_path then
      local f = io.open(default_theme_path, "r")
      if f then
         local code = f:read("*a")
         f:close()

         local chunk, err = load(code, "@" .. default_theme_path)
         if chunk then
            local success, theme = pcall(chunk)
            if success and type(theme) == "table" then
               for k, v in pairs(theme) do
                  merged[k] = v
               end
            end
         else
            print("ERROR: Failed to load default theme:", tostring(err))
         end
      end
   else
      -- Use cached default theme
      for k, v in pairs(default_theme) do
         merged[k] = v
      end
   end

   -- Load and merge user styles if they exist
   local f = io.open(user_styles_path, "r")
   if f then
      local code = f:read("*a")
      f:close()

      local chunk, err = load(code, "@" .. user_styles_path)
      if chunk then
         local success, user_styles = pcall(chunk)
         if success and type(user_styles) == "table" then
            for k, v in pairs(user_styles) do
               merged[k] = v
            end
         end
      else
         print("ERROR: Failed to load user styles:", tostring(err))
      end
   end

   current_theme = merged
   return current_theme
end

local Theme = load_theme()

-- Set up config directory and default bar.lua
local config_dir = os.getenv("HOME") .. "/.config/calisto"
local bar_config_path = config_dir .. "/bar.lua"

-- Create config directory if it doesn't exist
os.execute("mkdir -p " .. config_dir)

-- Create default bar.lua if it doesn't exist
local function create_default_bar_config()
   local f = io.open(bar_config_path, "r")
   if f then
      f:close()
      return -- File already exists
   end

   local default_config = [[local stopped = false

local bar = Widgets.bar:new {
   opacity = 0.5,
   font = "monospace",  -- Font family (e.g., "monospace", "sans-serif", "JetBrains Mono")
   font_size = 10,      -- Font size in points
   gap = 4,             -- Gap between widgets in pixels
   widgets = {
      Widgets.button:new {
         label = "Hello",
         css = css(Theme.Button),
         on_clicked = function()
            print("HERE!")
         end
      },
      Widgets.workspaces:new {
         css = css(Theme.Workspaces),
         gap = 2,  -- Gap between workspace buttons in pixels
      },
      -- Widgets.window:new {  -- Uncomment to show current window title
      --    css = css(Theme.Window),
      -- },
      Widgets.hspacer:new(),
      -- Widgets.media:new {  -- Uncomment to add media controls
      --    css = css(Theme.Media),
      -- },
      -- Widgets.audio:new {  -- Uncomment to show audio volume
      --    css = css(Theme.Audio),
      -- },
      -- Widgets.network:new {  -- Uncomment to show network status
      --    css = css(Theme.Network),
      -- },
      Widgets.clock:new {
         css = css(Theme.Clock),
         tick = function()
            return not stopped
         end
      },
   }
}

return bar, function() stopped = true end
]]

   f = io.open(bar_config_path, "w")
   if f then
      f:write(default_config)
      f:close()
   else
      error("Failed to create default bar config at " .. bar_config_path)
   end
end

create_default_bar_config()

-- Create default styles.lua if it doesn't exist
-- Note: theme.lua is reserved for wallust color palette
local function create_default_styles_config()
   local styles_config_path = config_dir .. "/styles.lua"
   local f = io.open(styles_config_path, "r")
   if f then
      f:close()
      return -- File already exists
   end

   local default_config = "-- Override default widget styles here\n" ..
      "-- This file lets you customize widget CSS while theme.lua is for wallust colors\n" ..
      "-- Available style keys: Button, Clock, Workspaces\n" ..
      "-- Example:\n" ..
      "-- {\n" ..
      "--    Button = [[\n" ..
      "--       button {\n" ..
      "--          background-color: {accent};\n" ..
      "--          color: {fg};\n" ..
      "--          border-radius: 8px;\n" ..
      "--       }\n" ..
      "--    ]],\n" ..
      "-- }\n" ..
      "\n" ..
      "{}\n"

   f = io.open(styles_config_path, "w")
   if f then
      f:write(default_config)
      f:close()
   else
      print("Warning: Failed to create default styles config at " .. styles_config_path)
   end
end

create_default_styles_config()

-- Load bar.lua with provided environment
local function load_bar_config()
   local f = io.open(bar_config_path, "r")
   if not f then
      error("Failed to open bar config at " .. bar_config_path)
   end

   local code = f:read("*a")
   f:close()

   -- Create environment with available modules
   local env = {
      Widgets = Widgets,
      UI = UI,
      Theme = Theme,
      css = css,
      -- Include standard library functions
      print = print,
      pairs = pairs,
      ipairs = ipairs,
      tostring = tostring,
      tonumber = tonumber,
      type = type,
      string = string,
      table = table,
      math = math,
      os = os,
      io = io,
   }

   -- Load the config with the custom environment
   local chunk, err = load(code, "@" .. bar_config_path, "t", env)
   if not chunk then
      error("Failed to load bar config: " .. tostring(err))
   end

   return chunk()
end

-- Create a container box to hold the current bar
local container = Gtk.Box {
   orientation = Gtk.Orientation.HORIZONTAL,
}

-- Track current bar and cleanup
local current_bar = nil
local current_cleanup = nil

-- Function to reload the bar
local function reload_bar()
   -- Clean up old bar
   if current_cleanup then
      current_cleanup()
   end
   if current_bar then
      container:remove(current_bar)
      current_bar = nil
   end

   -- Load new bar
   local success, bar, cleanup = pcall(load_bar_config)
   if not success then
      print("ERROR: Failed to load bar config:", tostring(bar))
      return
   end

   current_bar = bar
   current_cleanup = cleanup

   -- Add new bar to container
   if bar then
      container:append(bar)
   end
end

-- Initial load
reload_bar()

-- Function to reload theme and bar
local function reload_theme_and_bar()
   UI:reload_theme()  -- Reload wallust colors
   Theme = load_theme()  -- Reload widget styles
   -- Apply global CSS BEFORE creating widgets so they pick up new styles
   -- Use defaults for opacity/font since bar config hasn't been loaded yet
   -- Bar creation will call UI:apply_theme again with correct settings
   UI:apply_theme(0.5, "monospace", 10)
   reload_bar()
end

-- Set up file monitoring for bar config
local bar_file = Gio.File.new_for_path(bar_config_path)
local bar_monitor = bar_file:monitor_file(Gio.FileMonitorFlags.NONE, nil)

bar_monitor.on_changed = function(_mon, _file, _other_file, event_type)
   local event_name = tostring(event_type)
   if event_name == "CHANGES_DONE_HINT" or
      event_name == "CREATED" or
      event_name == "CHANGED" then
      GLib.timeout_add(GLib.PRIORITY_DEFAULT, 100, function()
         reload_bar()
         return false
      end)
   end
end

-- Note: src/theme.lua is already monitored by calisto.lua's poller
-- We only need to monitor user config files here

-- Set up file monitoring for wallust theme (theme.lua)
local wallust_theme_path = config_dir .. "/theme.lua"
local wallust_theme_file = Gio.File.new_for_path(wallust_theme_path)
local wallust_theme_monitor = wallust_theme_file:monitor_file(Gio.FileMonitorFlags.NONE, nil)

wallust_theme_monitor.on_changed = function(_mon, _file, _other_file, event_type)
   local event_name = tostring(event_type)
   if event_name == "CHANGES_DONE_HINT" or
      event_name == "CREATED" or
      event_name == "CHANGED" then
      GLib.timeout_add(GLib.PRIORITY_DEFAULT, 100, function()
         reload_theme_and_bar()
         return false
      end)
   end
end

-- Set up file monitoring for user styles (styles.lua)
local user_styles_path = config_dir .. "/styles.lua"
local user_styles_file = Gio.File.new_for_path(user_styles_path)
local user_styles_monitor = user_styles_file:monitor_file(Gio.FileMonitorFlags.NONE, nil)

user_styles_monitor.on_changed = function(_mon, _file, _other_file, event_type)
   local event_name = tostring(event_type)
   -- event_type is a string, not a number, so compare strings
   if event_name == "CHANGES_DONE_HINT" or
      event_name == "CREATED" or
      event_name == "CHANGED" then
      GLib.timeout_add(GLib.PRIORITY_DEFAULT, 100, function()
         reload_theme_and_bar()
         return false
      end)
   end
end

-- Return container and cleanup function
return container, function()
   if current_cleanup then
      current_cleanup()
   end
   if bar_monitor then
      bar_monitor:cancel()
   end
   if wallust_theme_monitor then
      wallust_theme_monitor:cancel()
   end
   if user_styles_monitor then
      user_styles_monitor:cancel()
   end
end
