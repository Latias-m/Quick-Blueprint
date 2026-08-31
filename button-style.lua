local default_gui = data.raw["gui-style"].default

local function add_white_background_style(style_name)
  default_gui[style_name] = {
    type = "button_style",
    parent = "slot_button",

    border = 2,
    border_color = { r = 0.1, g = 1, b = 0.1, a = 1 },

    default_graphical_set = {
      base = {
        position = { 0, 0 },
        corner_size = 8,
        tint = { r = 0., g = 1, b = 0.1, a = 0.3 }
      },
      shadow = {
        position = { 0, 0 },
        corner_size = 8
      }
    },

    hovered_graphical_set = {
      base = {
        position = { 0, 0 },
        corner_size = 8,
        tint = { r = 0.1, g = 1, b = 0.1, a = 0.1 }
      },
      shadow = {
        position = { 0, 0 },
        corner_size = 8
      }
    },

    clicked_graphical_set = {
      base = {
        position = { 0, 0 },
        corner_size = 8,
        tint = { r = 0.1, g = 1, b = 0.1, a = 0.1 }
      },
      shadow = {
        position = { 0, 0 },
        corner_size = 8
      }
    }
  }
end

add_white_background_style("quick-blueprint-selected-button")
