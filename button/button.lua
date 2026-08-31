
local common = require("common")
local mod_gui = require("mod-gui")
local self = {}

local MOD_NAME = common.MOD_NAME
local BUTTON_NAME = MOD_NAME .. "-open-button"

function self.ensure(player)
  local button_flow = mod_gui.get_button_flow(player)
  if button_flow[BUTTON_NAME] then
    return
  end

  local legacy_button = player.gui.top[BUTTON_NAME]
  if legacy_button and legacy_button.valid then
    legacy_button.destroy()
  end

  button_flow.add({
    type = "button",
    name = BUTTON_NAME,
    caption = {"quick-blueprint.button-title"}
  })
end

function self.handle_click(event)
  local element = event.element
  if element.name == BUTTON_NAME then
    return "window.open"
  end
end

return self
