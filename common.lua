local common = {
  MOD_NAME = "quick-blueprint",
  savekeys = {
    selected_recipe_name = "selected_recipe_name",
    selected_machine_name = "selected_machine_name",
    selected_transport_belt_name = "selected_transport_belt_name",
    selected_inserter_name = "selected_inserter_name",
    selected_electric_pole_name = "selected_electric_pole_name",
    selected_direction = "selected_direction",
    selected_count_mode = "selected_count_mode",
    selected_modules = "selected_modules"
  }
}

function common.starts_with(str, prefix)
  return str and prefix and string.sub(str, 1, string.len(prefix)) == prefix
end

local function get_storage_obj(player)
  storage.players = storage.players or {}
  storage.players[player.index] = storage.players[player.index] or {}
  return storage.players[player.index]
end

function common.set_storage_value(player, key, value)
  local obj = get_storage_obj(player)
  obj[key] = value
end

function common.get_storage_value(player, key)
  local obj = get_storage_obj(player)
  return obj[key]
end

function common.get_key(arr)
  table.sort(arr)
  return table.concat(arr, "|")
end

function common.get_selected_name(button_name, start)
  if not button_name or string.sub(button_name, 1, #start) ~= start then
    return nil
  end
  return string.sub(button_name, #start + 1)
end

return common
