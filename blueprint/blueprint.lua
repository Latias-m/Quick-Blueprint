local recipe = require("recipe.recipe")
local common = require("common")
local blueprint = {}
local entity_number = 1
local electric_entity_number = {}
local function get_config(player, print_recipt)
  local machine_key = common.savekeys.selected_machine_name ..
      common.get_key(recipe.get_recipe_categories(print_recipt))
  local machine_name = common.get_storage_value(player, machine_key)

  local transport_belt = common.get_storage_value(player, common.savekeys.selected_transport_belt_name)
  local inserter = common.get_storage_value(player, common.savekeys.selected_inserter_name)
  local electric_pole = common.get_storage_value(player, common.savekeys.selected_electric_pole_name)
  local direction = common.get_storage_value(player, common.savekeys.selected_direction)
  local count_mode = common.get_storage_value(player, common.savekeys.selected_count_mode) or "full"
  local module_selections = common.get_storage_value(player, common.savekeys.selected_modules) or {}
  local modules = module_selections[machine_name] or {}

  return {
    machine_name = machine_name,
    transport_belt = transport_belt,
    inserter = inserter,
    electric_pole = electric_pole,
    direction = direction,
    count_mode = count_mode,
    modules = modules
  }
end

local function add_arr(array1, array2)
  for _, value in ipairs(array2) do
    table.insert(array1, value)
  end
end

local function insert_entry(group, entry, startx)
  entry.position.x = entry.position.x + startx
  entry.entity_number = entity_number
  if entry.neighbours then
    if #electric_entity_number > 0 then
      for i = 1, 2 do
        if #electric_entity_number - i + 1 > 0 then
          table.insert(entry.neighbours, electric_entity_number[#electric_entity_number - i + 1])
        end
      end
    end
    table.insert(electric_entity_number, entity_number)
  end
  entity_number = entity_number + 1
  table.insert(group, entry)
  return entry.entity_number
end
local function get_machine_fluid_inputs(machine_name, target_type)
  local inputs = {}
  local proto = prototypes.entity[machine_name]
  if not proto then
    return inputs
  end

  local fluidboxes = proto.fluidbox_prototypes or proto.fluid_boxes
  if not fluidboxes then
    return inputs
  end

  for _, fb in ipairs(fluidboxes) do
    local is_match_fb = fb.production_type == target_type

    if fb.pipe_connections then
      for _, conn in ipairs(fb.pipe_connections) do
        local is_match_conn = is_match_fb
        if conn.flow_direction then
          is_match_conn = conn.flow_direction == target_type
        end

        if is_match_conn then
          local off_x, off_y = nil, nil
          if conn.position then
            off_x = (type(conn.position) == "table" and (conn.position.x or conn.position[1]))
            off_y = (type(conn.position) == "table" and (conn.position.y or conn.position[2]))
          elseif conn.positions then
            local p = conn.positions[1] or conn.positions[defines.direction.north] or
                conn.positions[defines.direction.south] or conn.positions[defines.direction.east] or
                conn.positions[defines.direction.west]
            if p and type(p) == "table" then
              off_x = p.x or p[1]
              off_y = p.y or p[2]
            end
          end

          if off_x and off_y then
            table.insert(inputs, {
              offset_x = off_x,
              offset_y = off_y,
              positions = conn.positions,
              direction = conn.direction,
              flow_direction = conn.flow_direction or fb.production_type
            })
          end
        end
      end
    end
  end

  return inputs
end

local function find_fluid_direction(count, inputs)
  if count <= 0 or #inputs == 0 then
    return {}
  end

  local directions = {}
  for _, input in ipairs(inputs) do
    local dir = input.direction
    directions[dir] = (directions[dir] or 0) + 1
  end

  local result = {}
  for dir_key, val in pairs(directions) do
    if val >= count then
      table.insert(result, dir_key)
    end
  end

  return result
end

local function find_same(in_group, out_group)
  for index, value in ipairs(in_group) do
    for index_out, v in ipairs(out_group) do
      if value == v then
        return value
      end
    end
  end
  return nil
end

local function get_rotated_fluid_port_position(direction, input, machine_width, machine_height)
  local w = machine_width or 3
  local h = machine_height or 3
  local dir_index = 1
  if direction == defines.direction.east then
    dir_index = 2
  elseif direction == defines.direction.south then
    dir_index = 3
  elseif direction == defines.direction.west then
    dir_index = 4
  end
  local rot_x, rot_y = nil, nil
  if input.positions and input.positions[dir_index] then
    local p = input.positions[dir_index]
    rot_x = p.x or p[1]
    rot_y = p.y or p[2]
  end
  if rot_x == nil or rot_y == nil then
    local ox = input.offset_x or 0
    local oy = input.offset_y or 0
    if dir_index == 2 then
      rot_x, rot_y = -oy, ox
    elseif dir_index == 3 then
      rot_x, rot_y = -ox, -oy
    elseif dir_index == 4 then
      rot_x, rot_y = oy, -ox
    else
      rot_x, rot_y = ox, oy
    end
  end
  local current_w, current_h = w, h
  if dir_index == 2 or dir_index == 4 then
    current_w, current_h = h, w
  end
  local center_x = math.floor(current_w / 2)
  local center_y = math.floor(current_h / 2)
  local final_x = rot_x + center_x
  local final_y = rot_y + center_y

  return {
    x = final_x,
    y = final_y
  }
end

local function get_trans_entry(y_list, width)
  local result = {}
  for index, value in ipairs(y_list) do
    for i = 1, width do
      table.insert(result, {
        name = value.name,
        position = { x = value.position.x + i - 1, y = value.position.y },
        direction = value.direction
      })
    end
  end

  return result
end

local function find(group, x, y)
  for index, value in ipairs(group) do
    if value.position.x == x and value.position.y == y then
      return value
    end
  end

  return false
end

local function find_empty_x(group, y)
  for i = 0, 10, 1 do
    if not find(group, i, y) then
      return i
    end
  end
  return nil
end

local function get_change_trans(direction)
  local change_position_list = {
    {
      y = 0,
      x = 1,
      direction = defines.direction.south
    },
    {
      y = 1,
      x = 0,
      direction = defines.direction.north
    },
    {
      y = 1,
      x = 1,
      direction = defines.direction.west
    },
    {
      y = 1,
      x = 2,
      direction = defines.direction.west
    },
  }
  if direction == "right" then
    direction = defines.direction.east
    change_position_list = {
      {
        y = 0,
        x = 1,
        direction = defines.direction.south
      },
      {
        y = 1,
        x = 0,
        direction = defines.direction.east
      },
      {
        y = 1,
        x = 1,
        direction = defines.direction.east
      },
      {
        y = 1,
        x = 2,
        direction = defines.direction.north
      },
    }
  end

  return change_position_list
end

local function set_unit(temp_group, config, is_change_mechine)
  local directions = {
    output = {
      [defines.direction.north] = defines.direction.south,
      [defines.direction.south] = defines.direction.north,
      [defines.direction.east] = defines.direction.east,
      [defines.direction.west] = defines.direction.west,
    },
    input = {
      [defines.direction.north] = defines.direction.north,
      [defines.direction.south] = defines.direction.south,
      [defines.direction.east] = defines.direction.west,
      [defines.direction.west] = defines.direction.east,
    }
  }

  local check_direction = nil
  local fluid_inputs = get_machine_fluid_inputs(config.machine_name, "input")
  local fluid_directions = find_fluid_direction(config.count_fluid, fluid_inputs)
  if config.count_fluid > 0 then
    if #fluid_directions == 0 then
      game.print("无法找到足够的流体输入口，请检查机器原型是否支持所需数量的流体输入。")
      return temp_group
    end

    for index, value in ipairs(fluid_directions) do
      if directions.input[value] then
        for index_t, value_t in ipairs(fluid_inputs) do
          if value_t.direction == value then
            fluid_inputs[index_t].end_direction = directions.input[value]
          end
        end

        fluid_directions[index] = directions.input[value]
      end
    end
  end

local fluid_out = get_machine_fluid_inputs(config.machine_name, "output")
  local fluid_out_directions = find_fluid_direction(config.product_count_fluid, fluid_out)
  if config.product_count_fluid > 0 then
    if #fluid_out == 0 then
      game.print("无法找到流体输出口，请检查机器原型是否支持流体输出。")
      return temp_group
    end
    for index, value in ipairs(fluid_out_directions) do
      if directions.output[value] then
        for index_t, value_t in ipairs(fluid_out) do
          if value_t.direction == value then
            fluid_out[index_t].end_direction = directions.output[value]
          end
        end

        fluid_out_directions[index] = directions.output[value]
      end
    end
  end
  if config.product_count_fluid > 0 and config.count_fluid > 0 then
    check_direction = find_same(fluid_directions, fluid_out_directions)
  elseif config.product_count_fluid > 0 then
    check_direction = fluid_out_directions[1]
  elseif config.count_fluid > 0 then
    check_direction = fluid_directions[1]
  end

  if check_direction == nil and (config.count_fluid > 0 or config.product_count_fluid > 0) then
    return
  end

  temp_group[1].direction = check_direction

  local input_list = {}
  for index, value in ipairs(fluid_inputs) do
    if value.end_direction == check_direction then
      table.insert(input_list,
        get_rotated_fluid_port_position(check_direction, value, config.machine.width, config.machine.height))
    end
  end
  table.sort(input_list, function(a, b)
    return a.x < b.x
  end)

  local output_list = {}
  for index, value in ipairs(fluid_out) do
    if value.end_direction == check_direction then
      table.insert(output_list,
        get_rotated_fluid_port_position(check_direction, value, config.machine.width, config.machine.height))
    end
  end
  table.sort(output_list, function(a, b)
    return a.x < b.x
  end)

  local use_transline = config.count_item + math.min(1, config.product_count_item)

  local y_position_list = {}
  local pipe_list = {}
  local start_y = -2
  if config.count_item > 0 then
    start_y = start_y - 3
  end
  for i = 1, config.count_fluid do
    if i > 1 then
      start_y = start_y - 2
    end

    y_position_list[i] = {
      name = "pipe",
      position = { x = 0, y = start_y },
    }

if i == 1 and start_y == -2 then
      table.insert(pipe_list, {
        name = "pipe",
        position = { x = input_list[i].x, y = -1 },
      })
    else
      table.insert(pipe_list, {
        name = "pipe-to-ground",
        position = { x = input_list[i].x, y = -1 },
        direction = defines.direction.south
      })
      table.insert(pipe_list, {
        name = "pipe-to-ground",
        position = { x = input_list[i].x, y = start_y + 1 },
        direction = defines.direction.north
      })
    end
  end

  local start_line = config.machine.height
  start_y = config.machine.height + 1
  if config.product_count_item > 0 then
    start_y = start_y + 3
    if use_transline > 3 then
      start_y = start_y + 1
    end
  end
  for i = 1, config.product_count_fluid do
    if i > 1 then
      start_y = start_y + 2
    end

    table.insert(y_position_list, {
      name = "pipe",
      position = { x = 0, y = start_y },
    })

    if i == 1 and start_y == config.machine.height + 1 then
      table.insert(pipe_list, {
        name = "pipe",
        position = { x = output_list[i].x, y = start_line },
      })
    else
      table.insert(pipe_list, {
        name = "pipe-to-ground",
        position = { x = output_list[i].x, y = start_line },
        direction = defines.direction.north
      })
      table.insert(pipe_list, {
        name = "pipe-to-ground",
        position = { x = output_list[i].x, y = start_y - 1 },
        direction = defines.direction.south
      })
    end
  end

  local trans_position = {
    {
      used = false,
      y = -2,
      type = 0
    },
    {
      used = false,
      y = -3,
      type = 1
    },
    {
      used = false,
      y = config.machine.height + 1,
      type = 0
    },
    {
      used = false,
      y = config.machine.height + 2,
      type = 1
    }
  }
  for i = 1, math.min(config.count_item, 3) do
    trans_position[i].used = true
    trans_position[i].direction_type = "in"
    table.insert(y_position_list, {
      name = config.transport_belt,
      position = { x = 0, y = trans_position[i].y },
      direction = defines.direction.east
    })
  end

  local direction = defines.direction.west
  if config.direction == "right" then
    direction = defines.direction.east
  end

  if config.product_count_item > 0 then
    local unusei = 3
    if trans_position[3].used then
      unusei = 4
    end
    trans_position[unusei].used = true
    trans_position[unusei].direction_type = "out"
    table.insert(y_position_list, {
      name = config.transport_belt,
      position = { x = 0, y = trans_position[unusei].y },
      direction = direction
    })
  end

  for i = 1, #trans_position do
    local fori = #trans_position - i + 1
    local transinfo = trans_position[fori]
    if transinfo.used then
      local line_y = -1
      if transinfo.y > 0 then
        line_y = config.machine.height
      end

      local x = find_empty_x(pipe_list, line_y)
      if x ~= nil then
        local inster = config.inserter
        if transinfo.type == 1 then
          inster = "long-handed-inserter"
        end

        local direction
        if line_y > 0 then
          if transinfo.direction_type == "in" then
            direction = defines.direction.south
          else
            direction = defines.direction.north
          end
        else
          if transinfo.direction_type == "in" then
            direction = defines.direction.north
          else
            direction = defines.direction.south
          end
        end

        table.insert(pipe_list, {
          name = inster,
          position = { x = x, y = line_y },
          direction = direction
        })
      end
    end
  end

  local x = find_empty_x(pipe_list, -1)
  if x ~= nil then
    table.insert(pipe_list, {
      name = config.electric_pole,
      position = { x = x, y = -1 },
      direction = defines.direction.north,
      neighbours = {}
    })
  end
  local elect_down_y = config.machine.height
  local is_use_elec = false
  for index, value in ipairs(pipe_list) do
    if value.position.y == elect_down_y and value.name ~= "pipe" and value.name ~= "pipe-to-ground" then
      is_use_elec = true
    end
  end
  if is_use_elec then
    local down_x = find_empty_x(pipe_list, elect_down_y)
    if down_x ~= nil then
      table.insert(pipe_list, {
        name = config.electric_pole,
        position = { x = down_x, y = elect_down_y },
        direction = defines.direction.north,
        neighbours = {}
      })
    end
  end

  local max_x = config.machine.width
  for index, value in ipairs(pipe_list) do
    max_x = math.max(max_x, value.position.x + 1)
  end

  local trans_entry = get_trans_entry(y_position_list, max_x)

  if is_change_mechine then
    local change_trans = get_change_trans(config.direction)
    local find_start_y = 0
    for index, value in ipairs(trans_position) do
      if value.direction_type == "out" then
        find_start_y = value.y
      end
    end
    for index, value in ipairs(change_trans) do
      local find_entry = find(trans_entry, value.x, find_start_y + value.y)
      if find_entry then
        find_entry.direction = value.direction
      else
        table.insert(trans_entry, {
          name = config.transport_belt,
          position = { x = value.x, y = find_start_y + value.y },
          direction = value.direction
        })
      end
    end
  end

add_arr(temp_group, trans_entry)
  add_arr(temp_group, pipe_list)
  return max_x
end

local function get_blueprint_module_items(modules)
  local items = {}
  local stack = 0
  for module_name, count in pairs(modules) do
    if type(count) == "number" and count > 0 then
      local positions = {}
      for _ = 1, math.floor(count) do
        table.insert(positions, {
          inventory = defines.inventory.assembling_machine_modules,
          stack = stack
        })
        stack = stack + 1
      end
      table.insert(items, {
        id = { name = module_name },
        items = { in_inventory = positions }
      })
    end
  end
  return next(items) and items or nil
end

local function get_unit(config, is_change_mechine)
  local temp_group = {
    {
      name = config.machine_name,
      position = { x = math.floor(config.machine.width / 2), y = math.floor(config.machine.height / 2) },
      recipe = config.recipe_name,
      items = get_blueprint_module_items(config.modules)
    }
  }

  local max_x = set_unit(temp_group, config, is_change_mechine)

  return temp_group, max_x
end

local function get_blueprint_entities(player, recipe_name)
  entity_number = 1
  electric_entity_number = {}
  local selected_recipe = recipe.get_recipe_by_name(recipe_name)
  if not selected_recipe then
    return nil, "recipe not found: " .. tostring(recipe_name)
  end

  local config = get_config(player, selected_recipe)
  if not config.machine_name then
    return nil, "no factory selected"
  end
  if not config.transport_belt or not config.inserter or not config.electric_pole then
    return nil, "incomplete blueprint configuration"
  end

  config.recipe_name = recipe_name

  local proto = prototypes.entity[config.machine_name]
  if not proto then
    return nil, "factory prototype not found: " .. config.machine_name
  end

  config.machine = {
    width = proto.tile_width or 1,
    height = proto.tile_height or 1
  }

  local ingredients = selected_recipe.ingredients or {}
  local count_fluid = 0
  local count_item = 0
  for _, ingredient in ipairs(ingredients) do
    if ingredient.type == "fluid" then
      count_fluid = count_fluid + 1
    elseif ingredient.type == "item" then
      count_item = count_item + 1
    end
  end

  config.count_fluid = count_fluid
  config.count_item = count_item

  local product_count_item = 0
  local product_count_fluid = 0
  local products = selected_recipe.products or {}
  for _, product in ipairs(products) do
    if product.type == "item" then
      product_count_item = product_count_item + 1
    else
      product_count_fluid = product_count_fluid + 1
    end
  end

  config.product_count_fluid = product_count_fluid
  config.product_count_item = product_count_item

  local cost_machine, out_machine_full = recipe.get_machine_count(selected_recipe, config.machine_name,
    config.transport_belt, config.modules)

  local machine_count = 1
  if config.count_mode == "1" then
    machine_count = 1
  elseif config.count_mode == "half" then
    machine_count = math.max(1, out_machine_full / 2)
  elseif config.count_mode == "out-half" then
    machine_count = math.max(1, math.ceil(out_machine_full / 2))
  elseif config.count_mode == "cost-full" then
    machine_count = math.max(1, cost_machine)
  else
    machine_count = math.max(1, out_machine_full)
  end

  local entities = {}
  local startx = 0

  local temp, max_x = get_unit(config, false)

  local temp_change = get_unit(config, true)
  for i = 1, machine_count do
    if math.ceil(out_machine_full / 2) == i then
      for index, value in ipairs(temp_change) do
        local copied_value = table.deepcopy(value)
        insert_entry(entities, copied_value, (i - 1) * max_x)
      end
    else
      for index, value in ipairs(temp) do
        local copied_value = table.deepcopy(value)
        insert_entry(entities, copied_value, (i - 1) * max_x)
      end
    end
  end

  return entities
end

function blueprint.set_blueprint(player, recipe_name)
  if not player or not player.valid then
    return false
  end

  local cursor = player.cursor_stack
  if not cursor or not cursor.valid then
    player.print({ "quick-blueprint.blueprint-generation-failed" })
    log("[Quick Blueprint] Blueprint generation failed: invalid cursor stack")
    return false
  end
  local entities, error_message = get_blueprint_entities(player, recipe_name)
  if not entities then
    player.print({ "quick-blueprint.blueprint-generation-failed" })
    log("[Quick Blueprint] Blueprint generation failed: " .. error_message)
    return false
  end

  player.clear_cursor()
  cursor.set_stack({ name = "blueprint", count = 1 })
  cursor.set_blueprint_entities(entities)
  return true
end

return blueprint
