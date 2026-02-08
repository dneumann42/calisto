local lgi  = require("lgi")
local Gtk  = lgi.require("Gtk", "4.0")
local Gdk  = lgi.require("Gdk", "4.0")
local pp = require("pprint") -- ADDED

local THEME_PATH = (os.getenv("HOME") or "") .. "/.config/calisto/theme.lua"

local function load_theme_styles()
   -- Force reload by clearing package cache
   package.loaded["theme"] = nil
   return require("theme")
end

local function load_wallust_theme()
   local f = io.open(THEME_PATH, "r")
   if not f then return nil end
   local src = f:read("a"); f:close()
   local chunk = load(src, "@" .. THEME_PATH)
   return chunk and chunk()
end

local function hex_rgba(hex, alpha)
   local r = tonumber(hex:sub(2,3), 16)
   local g = tonumber(hex:sub(4,5), 16)
   local b = tonumber(hex:sub(6,7), 16)
   return string.format("rgba(%d,%d,%d,%s)", r, g, b, alpha)
end

local default_theme = {
   bg          = "#1e1e2e",
   surface     = "#313244",
   surface_alt = "#45475a",
   fg          = "#cdd6f4",
   fg_alt      = "#bac2de",
   fg_muted    = "#585b70",
   border      = "#45475a",
   accent      = "#89b4fa",
   accent_alt  = "#74c7ec",
   success     = "#a6e3a1",
   warning     = "#f9e2af",
   error       = "#f38ba8",
   info        = "#89dceb",
   highlight   = "#585b70",
   urgent_bg   = "#bf616a",
   urgent_fg   = "#eceff4",
   hover_bg    = "#4c566a",
}

local UI  = {
   theme = load_wallust_theme() or default_theme,
   widget_height = 28
}

function UI:reload_theme()
   self.theme = load_wallust_theme() or default_theme
end

function UI:apply_theme(opacity, font, font_size, widget_height)
   opacity = opacity or 0.5
   font = font or "monospace"
   font_size = font_size or 10
   widget_height = widget_height or 28

   -- Store widget_height in UI object so css() function can access it
   self.widget_height = widget_height

   -- Reload theme styles to pick up any changes
   local Theme = load_theme_styles()

   -- Helper to replace color placeholders with fallback to defaults
   local function replace_colors(text)
      return text:gsub("{([%w_]+)}", function(key)
         -- Don't replace widget_height here - it will be replaced later
         if key == "widget_height" then
            return "{widget_height}"
         end
         local color = self.theme[key] or default_theme[key] or "#000000"
         if not color:match("^#%x%x%x%x%x%x$") then
            print("WARNING: Invalid color for key '" .. key .. "': " .. tostring(color))
         end
         return color
      end)
   end

   local win_css = replace_colors(string.format([[
      window {
         background-color: rgba(0, 0, 0, %f);
         color: {fg};
         font-family: %s;
         font-size: %dpt;
      }
   ]], opacity, font, font_size))

   local core_app_css = [[
      headerbar {
         background-color: {surface};
         color: {fg};
         border-bottom-color: {border};
      }
      button {
         background-color: {surface};
         color: {fg};
         border-color: {border};
      }
      button:hover {
         background-color: {surface_alt};
      }
      button:active {
         background-color: {accent};
         color: {bg};
      }
      button.suggested-action {
         background-color: {accent};
         color: {bg};
         border-color: {accent};
      }
      button.destructive-action {
         background-color: {error};
         color: {bg};
         border-color: {error};
      }
      entry {
         background-color: {surface};
         color: {fg};
         border-color: {border};
         caret-color: {fg};
      }
      entry:focus {
         border-color: {accent};
      }
      entry placeholder {
         color: {fg_muted};
      }
      label {
         color: {fg};
      }
      popover {
         background-color: {surface};
         border-color: {border};
      }
      menu {
         background-color: {surface};
         border-color: {border};
      }
      menuitem:hover {
         background-color: {highlight};
      }
      row {
         color: {fg};
         border-bottom-color: {border};
      }
      row:hover {
         background-color: {highlight};
      }
      row:selected {
         background-color: {accent};
         color: {bg};
      }
      progressbar {
         background-color: {surface};
      }
      progressbar bar {
         background-color: {accent_alt};
      }
      scale trough {
         background-color: {surface};
      }
      scale slider {
         background-color: {accent};
      }
      scrollbar trough {
         background-color: {bg};
      }
      scrollbar slider {
         background-color: {fg_muted};
      }
      checkbutton check {
         background-color: {surface};
         border-color: {border};
      }
      checkbutton check:checked {
         background-color: {accent};
         border-color: {accent};
      }
      switch slider {
         background-color: {surface};
         border-color: {border};
      }
      switch:checked slider {
         background-color: {accent};
      }
      .success { color: {success}; }
      .warning { color: {warning}; }
      .error   { color: {error}; }
      .info    { color: {info}; }
   ]]

   local themed_core_app_css = replace_colors(core_app_css)
   local themed_workspaces_css = Theme and Theme.Workspaces and replace_colors(Theme.Workspaces) or ""
   local themed_media_css = Theme and Theme.Media and replace_colors(Theme.Media) or ""
   local themed_window_css = Theme and Theme.Window and replace_colors(Theme.Window) or ""
   local themed_audio_css = Theme and Theme.Audio and replace_colors(Theme.Audio) or ""
   local themed_network_css = Theme and Theme.Network and replace_colors(Theme.Network) or ""

   local css = win_css .. themed_core_app_css .. themed_workspaces_css .. themed_media_css .. themed_window_css .. themed_audio_css .. themed_network_css

   -- Replace widget_height placeholder
   css = css:gsub("{widget_height}", widget_height .. "px")

   -- swap provider so repeated import() calls don't accumulate them
   local display = Gdk.Display.get_default()
   if _G._calisto_css then
      Gtk.StyleContext.remove_provider_for_display(display, _G._calisto_css)
   end
   local provider = Gtk.CssProvider.new()
   provider:load_from_string(css)
   Gtk.StyleContext.add_provider_for_display(
      display, provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
   )
   _G._calisto_css = provider
end

UI:apply_theme()

return UI
