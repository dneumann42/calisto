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
     border-radius: 0px;
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
      border-radius: 0px;
      padding: 0px 8px;
      margin: 0px 2px;
      box-shadow: none;
      min-height: {widget_height};
  }
  .workspace.focused {
     background-color: {accent}; /* Focused background color */
     color: {fg_alt}; /* Focused text color */
  }
  .workspace.urgent {
     background-color: {urgent_bg}; /* Urgent background color */
     color: {urgent_fg}; /* Urgent text color */
  }
  .workspace.occupied {
     background-color: {surface_alt}; /* Occupied background color */
     color: {fg}; /* Occupied text color */
  }
  .workspace:hover {
     background-color: {hover_bg}; /* Hover background color */
  }
  ]],
    Media = [[
  .media-pill-left {
     background-image: linear-gradient(135deg, {success}, {surface});
     color: {fg};
     border-style: solid;
     border-width: 2px;
     border-top-color: {success};
     border-left-color: {success};
     border-bottom-color: {bg};
     border-right-color: {bg};
     border-radius: 0px;
     padding: 0px 8px;
     margin: 0px 0px 0px 2px;
     min-height: {widget_height};
  }
  .media-pill-middle {
     background-image: linear-gradient(135deg, {success}, {surface});
     color: {fg};
     border-style: solid;
     border-width: 2px;
     border-top-color: {success};
     border-left-color: {success};
     border-bottom-color: {bg};
     border-right-color: {bg};
     border-radius: 0px;
     padding: 0px 8px;
     margin: 0px 0px;
     min-height: {widget_height};
  }
  .media-pill-right {
     background-image: linear-gradient(135deg, {success}, {surface});
     color: {fg};
     border-style: solid;
     border-width: 2px;
     border-top-color: {success};
     border-left-color: {success};
     border-bottom-color: {bg};
     border-right-color: {bg};
     border-radius: 0px;
     padding: 0px 8px;
     margin: 0px 2px 0px 0px;
     min-height: {widget_height};
  }
  .media-pill-left:hover, .media-pill-middle:hover, .media-pill-right:hover {
     background-image: linear-gradient(135deg, {success}, {surface_alt});
     border-top-color: {success};
     border-left-color: {success};
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
     border-radius: 0px;
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
     border-radius: 0px;
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
     border-radius: 0px;
     padding: 0px 8px;
     margin: 0px 2px;
     min-height: {widget_height};
  }
  ]],
}
