return {
   Button = [[
   button {
      background-image: linear-gradient(135deg, {accent}, {surface});
      color: {fg};
      border: 1px solid {accent};
      border-radius: 12px;
      padding: 0px 8px;
      margin: 0px 2px;
   }
   button:hover {
      background-image: linear-gradient(135deg, {surface}, {surface_alt});
      border-color: {border};
   }
   button:active {
      background-image: linear-gradient(135deg, {surface}, {accent});
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
