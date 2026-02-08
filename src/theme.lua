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
      border-radius: 3px;
      padding: 2px 8px;
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
     padding: 0px 8px;
     margin: 0px 2px;
     border-radius: 12px; /* Consistent with other buttons */
     color: {fg}; /* Default text color */
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
}
