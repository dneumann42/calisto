return {
    Button = [[
   button {
      background-color: {surface_alt};
      color: {fg};
      border-style: solid;
      border-width: 2px;
      border-top-color: {fg_alt};
      border-left-color: {fg_alt};
      border-bottom-color: {bg};
      border-right-color: {bg};
      border-radius: 0px;
      padding: 0px 8px;
      margin: 0px 2px;
      box-shadow: none;
      min-height: {widget_height};
   }
   button:hover {
      background-color: {hover_bg};
      border-top-color: {accent};
      border-left-color: {accent};
   }
   button:active {
      background-color: {surface};
      border-top-color: {bg};
      border-left-color: {bg};
      border-bottom-color: {fg_alt};
      border-right-color: {fg_alt};
   }
  ]],
    Clock = [[
  label {
     background-image: linear-gradient(135deg, {accent_alt}, {surface});
     color: {fg};
     border-style: solid;
     border-width: 2px;
     border-top-color: {accent_alt};
     border-left-color: {accent_alt};
     border-bottom-color: {bg};
     border-right-color: {bg};
     border-radius: 32px;
     padding: 0px 8px;
     margin: 0px 2px;
     min-height: {widget_height};
  }
  ]],
    Workspaces = [[
  .workspace {
      background-color: {surface_alt};
      color: {fg};
      border-style: solid;
      border-width: 2px;
      border-top-color: {fg_alt};
      border-left-color: {fg_alt};
      border-bottom-color: {bg};
      border-right-color: {bg};
      border-radius: 32px;
      padding: 0px 8px;
      margin: 0px 2px;
      box-shadow: none;
      min-height: {widget_height};
  }
  .workspace.focused {
     background-image: linear-gradient(135deg, {accent}, {accent_alt});
     color: {bg};
     border-top-color: {accent};
     border-left-color: {accent};
     border-bottom-color: {bg};
     border-right-color: {bg};
     font-weight: bold;
  }
  .workspace.urgent {
     background-image: linear-gradient(135deg, {error}, {urgent_bg});
     color: {urgent_fg};
     border-top-color: {error};
     border-left-color: {error};
  }
  .workspace.occupied {
     background-color: {surface_alt};
     color: {fg};
  }
  .workspace:hover {
     background-color: {hover_bg};
     border-top-color: {accent_alt};
     border-left-color: {accent_alt};
  }
  ]],
    Media = [[
  button.media-pill-left {
     background-image: linear-gradient(135deg, {success}, {surface});
     color: {fg};
     border-style: solid;
     border-width: 2px;
     border-top-color: {success};
     border-left-color: {success};
     border-bottom-color: {bg};
     border-right-color: {bg};
     border-top-left-radius: 12px;
     border-bottom-left-radius: 12px;
     padding: 0px 8px;
     margin: 0px;
     border-right-width: 1px;
     min-height: {widget_height};
  }
  button.media-pill-middle {
     background-image: linear-gradient(135deg, {success}, {surface});
     color: {fg};
     border-style: solid;
     border-width: 2px;
     border-top-color: {success};
     border-left-color: transparent;
     border-bottom-color: {bg};
     border-right-color: transparent;
     padding: 0px 8px;
     margin: 0px;
     min-height: {widget_height};
  }
  box.media-pill-right {
     background-image: linear-gradient(135deg, {success}, {surface});
     color: {fg};
     border-style: solid;
     border-width: 2px;
     border-top-color: {success};
     border-left-color: transparent;
     border-bottom-color: {bg};
     border-right-color: {bg};
     border-top-right-radius: 12px;
     border-bottom-right-radius: 12px;
     padding: 0px 8px;
     margin: 0px 2px 0px 0px;
     min-height: {widget_height};
  }
  button.media-pill-left:hover, button.media-pill-middle:hover, box.media-pill-right:hover {
     background-image: linear-gradient(135deg, {success}, {surface_alt});
  }
  ]],
    Window = [[
  .window-widget {
     background-image: linear-gradient(135deg, {info}, {surface});
     color: {fg};
     border-style: solid;
     border-width: 2px;
     border-top-color: {info};
     border-left-color: {info};
     border-bottom-color: {bg};
     border-right-color: {bg};
     border-radius: 32px;
     padding: 0px 8px;
     margin: 0px 2px;
     min-height: {widget_height};
  }
  ]],
    Audio = [[
  .audio-widget {
     background-image: linear-gradient(135deg, {warning}, {surface});
     color: {fg};
     border-style: solid;
     border-width: 2px;
     border-top-color: {warning};
     border-left-color: {warning};
     border-bottom-color: {bg};
     border-right-color: {bg};
     border-radius: 32px;
     padding: 0px 8px;
     margin: 0px 2px;
     min-height: {widget_height};
  }
  ]],
    Network = [[
  .network-widget {
     background-image: linear-gradient(135deg, {accent}, {surface});
     color: {fg};
     border-style: solid;
     border-width: 2px;
     border-top-color: {accent};
     border-left-color: {accent};
     border-bottom-color: {bg};
     border-right-color: {bg};
     border-radius: 32px;
     padding: 0px 8px;
     margin: 0px 2px;
     min-height: {widget_height};
  }
  ]],
    Systray = [[
  .systray-widget {
     background-image: linear-gradient(135deg, {info}, {surface});
     color: {fg};
     border-style: solid;
     border-width: 2px;
     border-top-color: {info};
     border-left-color: {info};
     border-bottom-color: {bg};
     border-right-color: {bg};
     border-radius: 32px;
     padding: 0px 4px;
     margin: 0px 2px;
     min-height: {widget_height};
  }
  .tray-item {
     background-color: transparent;
     color: {fg};
     border: none;
     border-radius: 0px;
     padding: 0px 8px;
     margin: 0px;
     box-shadow: none;
     min-height: {widget_height};
  }
  .tray-item:hover {
     background-color: {hover_bg};
  }
  .tray-item:active {
     background-color: {surface};
  }
  ]],
}
