local lgi  = require("lgi")
local Gtk  = lgi.require("Gtk", "4.0")
local Gdk  = lgi.require("Gdk", "4.0")
local pp = require("pprint") -- ADDED

local THEME_PATH = (os.getenv("HOME") or "") .. "/.config/calisto/theme.lua"

local Theme = require("theme")

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

local UI  = {
   theme = load_wallust_theme() or {
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
      urgent_bg   = "#bf616a", -- Example urgent background
      urgent_fg   = "#eceff4", -- Example urgent foreground
      hover_bg    = "#4c566a", -- Example hover background
   }
}

function UI:apply_theme(opacity, font, font_size)
   opacity = opacity or 0.5
   font = font or "monospace"
   font_size = font_size or 10

   local win_css = string.format([[
      window {
         background-color: rgba(0, 0, 0, %f);
         color: {fg};
         font-family: %s;
         font-size: %dpt;
      }
   ]], opacity, font, font_size):gsub("{([%w_]+)}", self.theme)

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

   local themed_core_app_css = core_app_css:gsub("{([%w_]+)}", self.theme)
   local themed_workspaces_css = Theme.Workspaces:gsub("{([%w_]+)}", self.theme)
   print("Themed Workspaces CSS (before concatenation):", themed_workspaces_css)

   local css = win_css .. themed_core_app_css .. themed_workspaces_css

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
