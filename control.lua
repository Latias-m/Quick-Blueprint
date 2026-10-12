local button = require("button.button")
local config = require("gui.config")
local common = require("common")
local util = require("util")
local control = {}
local event_list = {
  button = button,
  config = config,
  control = control
}

function control.close_all(event)
  config.close(event)
end

local function get_player(player_index)
  local player = game.get_player(player_index)
  if player and player.valid then
    return player
  end
  return nil
end

script.on_init(function()
  for _, player in pairs(game.players) do
    button.ensure(player)
  end
end)

script.on_event(defines.events.on_player_created, function(event)
  local player = get_player(event.player_index)
  if player then
    button.ensure(player)
  end
end)

script.on_event(defines.events.on_player_joined_game, function(event)
  local player = get_player(event.player_index)
  if player then
    button.ensure(player)
  end
end)

-- A handler returns true to say it is done, a "module.function" string to
-- delegate, and nothing to let the next module look at the same click.
local function dispatch(event, handler_name)
  local element = event.element
  if not element or not element.valid then
    return
  end

  if not common.starts_with(element.name, common.MOD_NAME) then
    return
  end

  local player = get_player(event.player_index)
  if not player then
    return
  end

  for _, module in pairs(event_list) do
    local handler = module[handler_name]
    if handler then
      local result = handler(event)
      if result then
        if result == true then
          return
        end

        local list = util.split(result, ".")
        event_list[list[1]][list[2]](event)
        return
      end
    end
  end
end

script.on_event({ defines.events.on_gui_click, defines.events.on_gui_checked_state_changed }, function(event)
  dispatch(event, "handle_click")
end)

script.on_event(defines.events.on_gui_elem_changed, function(event)
  dispatch(event, "handle_elem_changed")
end)

script.on_event(defines.events.on_gui_closed, function(event)
  local element = event.element
  if element and element.valid and config.is_frame(element) then
    control.close_all(event)
  end
end)
