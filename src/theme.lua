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
     border: 1px solid {accent_alt};
     border-radius: 12px;
     padding: 0px 8px;
     margin: 0px 2px;
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
     border-top: 1px solid {success};
     border-bottom: 1px solid {success};
     border-left: 1px solid {success};
     border-right: 0.5px solid {success};
     border-radius: 12px 0 0 12px;
     padding: 0px 8px;
     margin: 0px 0px 0px 2px;
  }
  .media-pill-middle {
     background-image: linear-gradient(135deg, {success}, {surface});
     color: {fg};
     border-top: 1px solid {success};
     border-bottom: 1px solid {success};
     border-right: 0.5px solid {success};
     border-left: 0.5px solid {success};
     border-radius: 0;
     padding: 0px 8px;
     margin: 0px 0px;
  }
  .media-pill-right {
     background-image: linear-gradient(135deg, {success}, {surface});
     color: {fg};
     border-top: 1px solid {success};
     border-bottom: 1px solid {success};
     border-right: 1px solid {success};
     border-left: 0.5px solid {success};
     border-radius: 0 12px 12px 0;
     padding: 0px 8px;
     margin: 0px 2px 0px 0px;
  }
  .media-pill-left:hover, .media-pill-middle:hover, .media-pill-right:hover {
     background-image: linear-gradient(135deg, {success}, {surface_alt});
     border-color: {success};
  }
  ]],
}
