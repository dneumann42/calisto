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
}
