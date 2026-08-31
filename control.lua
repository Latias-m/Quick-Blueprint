local button = require("button.button")
local window = require("gui.window")
local common = require("common")
local config = require("gui.config")
local util = require("util")
local control = {}
local event_click_list = {
  button = button,
  window = window,
  config = config,
  control = control
}

function control.close_all(event)
  window.close(event)
  config.close(event)
end

local function get_player(player_index)
  local player = game.get_player(player_index)
  if player and player.valid then
    return player
  end
  return nil
end

local function request_recipe_translations(player)
  if not player or not player.valid then
    return
  end

  local cached = common.get_storage_value(player, common.savekeys.recipe_name_list)
  if cached and next(cached) ~= nil then
    return
  end

  storage.translation_requests = storage.translation_requests or {}
  storage.translation_requests[player.index] = storage.translation_requests[player.index] or {}

  for name, proto in pairs(prototypes.recipe) do
    if proto and proto.localised_name then
      local req_id = player.request_translation(proto.localised_name)
      if req_id then
        storage.translation_requests[player.index][req_id] = name
      end
    end
  end
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
    request_recipe_translations(player)
  end
end)

script.on_event(defines.events.on_string_translated, function(event)
  if not event.translated then
    return
  end

  local player = get_player(event.player_index)
  if not player then
    return
  end

  local player_requests = storage.translation_requests and storage.translation_requests[player.index]
  if not player_requests then
    return
  end

  local recipe_name = player_requests[event.id]
  if recipe_name then
    player_requests[event.id] = nil
    local list = common.get_storage_value(player, common.savekeys.recipe_name_list) or {}
    list[recipe_name] = event.result
    common.set_storage_value(player, common.savekeys.recipe_name_list, list)
  end
end)

script.on_event({ defines.events.on_gui_click, defines.events.on_gui_checked_state_changed }, function(event)
  local element = event.element
  if not element or not element.valid then
    return
  end

  if common.starts_with(element.name, common.MOD_NAME) then
    local player = get_player(event.player_index)
    if not player then
      return
    end

    for _, value in pairs(event_click_list) do
      if value.handle_click then
        local result = value.handle_click(event)
        if result then
          if result == true then
            return
          end
          
          local list = util.split(result, ".")
          event_click_list[list[1]][list[2]](event)
          return
        end
      end
    end
  end
end)

script.on_event(defines.events.on_gui_closed, function(event)
  local element = event.element
  if element and element.valid and window.is_window(element)then
    control.close_all(event)
  end
end)
