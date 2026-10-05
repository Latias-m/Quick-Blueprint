local common = require("common")
local myRecipe = require("recipe.recipe")
local blueprint = require("blueprint.blueprint")
local self = {}
local START_NAME = common.MOD_NAME .. "-config-"
local FRAME_NAME = START_NAME .. "-gui"
local CLOSE_NAME = START_NAME .. "-close-button-"
local RECIPE_BUTTON_NAME = START_NAME .. "-recipe-button"
local CONFIRM_NAME = START_NAME .. "-confirm-button-"
local MACHINE_BUTTON_NAME = START_NAME .. "-machine-button-"
local TRANSPORT_BELT_BUTTON_NAME = START_NAME .. "-transport-belt-button-"
local INSERTER_BUTTON_NAME = START_NAME .. "-inserter-button-"
local ELECTRIC_POLE_BUTTON_NAME = START_NAME .. "-electric-pole-button-"
local DIRECTION_NAME = START_NAME .. "-direction-button-"
local COUNT_MODE_NAME = START_NAME .. "-count-mode-button-"
local MODULE_SELECTOR_NAME = START_NAME .. "-module-selector"
local MODULE_SELECTOR_CONTAINER_NAME = START_NAME .. "-module-selector-container"
local MODULE_ADD_PREFIX = START_NAME .. "-module-add-"
local MODULE_REMOVE_PREFIX = START_NAME .. "-module-remove-"

local event_list = {}
local refresh_module_selector

local function find_parent(element, name)
    local parent = element
    while parent and parent.valid do
        if parent.name == name then
            return parent
        end
        parent = parent.parent
    end
    return nil
end

local function supports_effect(machine, effect_name)
    local effects = machine.allowed_effects or {}
    if effects[effect_name] then
        return true
    end
    for _, effect in ipairs(effects) do
        if effect == effect_name then
            return true
        end
    end
    return false
end

local function get_module_bonus(effect)
    if type(effect) == "table" then
        return effect.bonus
    end
    return effect
end

local function get_available_modules(machine)
    local modules = {}
    if not machine or (machine.module_inventory_size or 0) <= 0 then
        return modules
    end

    for _, item in pairs(prototypes.item) do
        local effects = item.module_effects
        local speed_bonus = effects and get_module_bonus(effects.speed)
        local consumption_bonus = effects and get_module_bonus(effects.consumption)
        local has_speed = type(speed_bonus) == "number"
        local has_consumption = type(consumption_bonus) == "number"
        local has_productivity = effects and type(get_module_bonus(effects.productivity)) == "number"

        if item.type == "module" and (has_speed or has_consumption) and not has_productivity then
            local supports_speed = not has_speed or supports_effect(machine, "speed")
            local supports_consumption = not has_consumption or supports_effect(machine, "consumption")
            if supports_speed and supports_consumption then
                table.insert(modules, item)
            end
        end
    end

    table.sort(modules, function(a, b)
        return a.name < b.name
    end)
    return modules
end

local function get_selected_modules(player, machine_name, available_modules, slot_count)
    local selections = common.get_storage_value(player, common.savekeys.selected_modules) or {}
    local selected_modules = selections[machine_name] or {}
    local available_names = {}
    local sanitized_modules = {}
    local used_slots = 0

    for _, module in ipairs(available_modules) do
        available_names[module.name] = true
    end
    for module_name, count in pairs(selected_modules) do
        if available_names[module_name] and type(count) == "number" and count > 0 then
            local allowed_count = math.min(math.floor(count), slot_count - used_slots)
            if allowed_count > 0 then
                sanitized_modules[module_name] = allowed_count
                used_slots = used_slots + allowed_count
            end
        end
    end

    selections[machine_name] = sanitized_modules
    common.set_storage_value(player, common.savekeys.selected_modules, selections)
    return sanitized_modules, used_slots
end

refresh_module_selector = function(player, container, recipe)
    local existing = container[MODULE_SELECTOR_NAME]
    if existing and existing.valid then
        existing.destroy()
    end

    local machine_key = common.savekeys.selected_machine_name .. common.get_key(myRecipe.get_recipe_categories(recipe))
    local machine_name = common.get_storage_value(player, machine_key)
    local machine = machine_name and prototypes.entity[machine_name]
    local slot_count = machine and machine.module_inventory_size or 0
    local available_modules = get_available_modules(machine)
    if slot_count <= 0 or #available_modules == 0 then
        return
    end

    local selected_modules, used_slots = get_selected_modules(player, machine_name, available_modules, slot_count)
    local parent = container.add({
        type = "flow",
        name = MODULE_SELECTOR_NAME,
        direction = "vertical"
    })
    parent.add({
        type = "label",
        caption = { "quick-blueprint.modules" }
    })

    local selected_row = parent.add({
        type = "flow",
        direction = "horizontal"
    })
    if next(selected_modules) then
        selected_row.add({
            type = "label",
            caption = { "quick-blueprint.selected-modules" }
        })
    end
    for _, module in ipairs(available_modules) do
        local count = selected_modules[module.name]
        if count then
            local selected_module = selected_row.add({
                type = "flow",
                direction = "horizontal"
            })
            local selected_module_button = selected_module.add({
                type = "sprite-button",
                name = MODULE_REMOVE_PREFIX .. module.name,
                sprite = "item/" .. module.name,
                tooltip = module.localised_name
            })
            selected_module_button.style.width = 20
            selected_module_button.style.height = 20
            selected_module.add({
                type = "label",
                caption = "x" .. count
            })
        end
    end
    selected_row.add({
        type = "label",
        caption = { "quick-blueprint.remaining-module-slots", slot_count - used_slots }
    })

    local available_row = parent.add({
        type = "table",
        column_count = 6
    })
    for _, module in ipairs(available_modules) do
        available_row.add({
            type = "sprite-button",
            name = MODULE_ADD_PREFIX .. module.name,
            sprite = "item/" .. module.name,
            tooltip = module.localised_name
        })
    end
end

local function update_button_state_by_group(group, button_name)
    for i = 1, #group do
        if group[i].name == button_name then
            group[i].style = "quick-blueprint-selected-button"
        else
            group[i].style = "slot_button"
        end
    end
end

local function update_radiobutton_state_by_group(group, selected_name)
    for i = 1, #group do
        group[i].state = (group[i].name == selected_name)
    end
end

local function add_machine_selector(player, frame, recipe)
    if not recipe then
        return
    end
    local parent = frame.add({
        type = "flow",
        direction = "vertical"
    })

local label_row = parent.add({
        type = "flow",
        direction = "horizontal"
    })
    label_row.add({
        type = "label",
        caption = { "quick-blueprint.machine" }
    })

    local machine_row = parent.add({
        type = "flow",
        direction = "horizontal"
    })
    local module_container = parent.add({
        type = "flow",
        name = MODULE_SELECTOR_CONTAINER_NAME,
        direction = "vertical"
    })

    local group = {}
    local machine_list = myRecipe.get_allowed_machines_for_recipe(recipe)

    local savekey = common.savekeys.selected_machine_name .. common.get_key(myRecipe.get_recipe_categories(recipe))
    local save_machine_name = common.get_storage_value(player, savekey)
    local check = false
    for i = 1, #machine_list do
        local machine = machine_list[i]

        if save_machine_name and machine.name == save_machine_name then
            check = true
            table.insert(group, machine_row.add({
                type = "sprite-button",
                name = MACHINE_BUTTON_NAME .. machine.name,
                sprite = "entity/" .. machine.name,
                tooltip = machine.localised_name or machine.name,
                style = "quick-blueprint-selected-button"
            }))
        else
            table.insert(group, machine_row.add({
                type = "sprite-button",
                name = MACHINE_BUTTON_NAME .. machine.name,
                sprite = "entity/" .. machine.name,
                tooltip = machine.localised_name or machine.name,
                style = "slot_button"
            }))
        end
    end

    if check == false then
        save_machine_name = nil
    end

    if not save_machine_name and machine_list[1] and group[1] then
        save_machine_name = machine_list[1] and machine_list[1].name
        common.set_storage_value(player, savekey, save_machine_name)
        group[1].style = "quick-blueprint-selected-button"
    end

    table.insert(event_list, function(event)
        if common.starts_with(event.element.name, MACHINE_BUTTON_NAME) then
            local selected_machine_name = common.get_selected_name(event.element.name, MACHINE_BUTTON_NAME)
            update_button_state_by_group(group, event.element.name)
            common.set_storage_value(player, savekey, selected_machine_name)
            refresh_module_selector(player, module_container, recipe)
            return true
        end
    end)
    return module_container
end

local function get_all_transport_belts()
    local belts = {}

    for _, prototype in pairs(prototypes.entity) do
        if prototype and prototype.type == "transport-belt" and not prototype.hidden then
            table.insert(belts, prototype)
        end
    end

    return belts
end

local function get_all_inserters()
    local inserters = {}

    for _, prototype in pairs(prototypes.entity) do
        if prototype and prototype.type == "inserter" and not prototype.hidden and prototype.name ~= "long-handed-inserter" then
            table.insert(inserters, prototype)
        end
    end

    return inserters
end

local function add_transport_belt_selector(player, frame)
    local parent = frame.add({
        type = "flow",
        direction = "vertical"
    })
    local label_row = parent.add({
        type = "flow",
        direction = "horizontal"
    })
    label_row.add({
        type = "label",
        caption = { "quick-blueprint.transport-belt" }
    })

    local transport_belt_row = parent.add({
        type = "flow",
        direction = "horizontal"
    })

    local transport_belt_list = get_all_transport_belts()
    local savekey = common.savekeys.selected_transport_belt_name
    local saveval = common.get_storage_value(player, savekey)
    local group = {}
    local check = false
    for i = 1, #transport_belt_list do
        local transport_belt = transport_belt_list[i]
        if saveval and transport_belt.name == saveval then
            check = true
            table.insert(group, transport_belt_row.add({
                type = "sprite-button",
                name = TRANSPORT_BELT_BUTTON_NAME .. transport_belt.name,
                sprite = "entity/" .. transport_belt.name,
                tooltip = transport_belt.localised_name or transport_belt.name,
                style = "quick-blueprint-selected-button"
            }))
        else
            table.insert(group, transport_belt_row.add({
                type = "sprite-button",
                name = TRANSPORT_BELT_BUTTON_NAME .. transport_belt.name,
                sprite = "entity/" .. transport_belt.name,
                tooltip = transport_belt.localised_name or transport_belt.name,
                style = "slot_button"
            }))
        end
    end

    if check == false then
        saveval = nil
    end
    if not saveval and transport_belt_list[1] and group[1] then
        saveval = transport_belt_list[1] and transport_belt_list[1].name
        common.set_storage_value(player, savekey, saveval)
        group[1].style = "quick-blueprint-selected-button"
    end

    table.insert(event_list, function(event)
        if common.starts_with(event.element.name, TRANSPORT_BELT_BUTTON_NAME) then
            update_button_state_by_group(group, event.element.name)
            common.set_storage_value(player, savekey,
                common.get_selected_name(event.element.name, TRANSPORT_BELT_BUTTON_NAME))
            return true
        end
    end)
end

local function add_inserter_selector(player, frame)
    local parent = frame.add({
        type = "flow",
        direction = "vertical"
    })

    local label_row = parent.add({
        type = "flow",
        direction = "horizontal"
    })
    label_row.add({
        type = "label",
        caption = { "quick-blueprint.inserter" }
    })

    local inserter_row = parent.add({
        type = "flow",
        direction = "horizontal"
    })

    local inserter_list = get_all_inserters()
    local group = {}
    local savekey = common.savekeys.selected_inserter_name
    local saveval = common.get_storage_value(player, savekey)
    local check = false

    for i = 1, #inserter_list do
        local inserter = inserter_list[i]

        if saveval and inserter.name == saveval then
            check = true
            table.insert(group, inserter_row.add({
                type = "sprite-button",
                name = INSERTER_BUTTON_NAME .. inserter.name,
                sprite = "entity/" .. inserter.name,
                tooltip = inserter.localised_name or inserter.name,
                style = "quick-blueprint-selected-button"
            }))
        else
            table.insert(group, inserter_row.add({
                type = "sprite-button",
                name = INSERTER_BUTTON_NAME .. inserter.name,
                sprite = "entity/" .. inserter.name,
                tooltip = inserter.localised_name or inserter.name,
                style = "slot_button"
            }))
        end
    end

    if check == false then
        saveval = nil
    end

    if not saveval and inserter_list[1] and group[1] then
        saveval = inserter_list[1] and inserter_list[1].name
        common.set_storage_value(player, savekey, saveval)
        group[1].style = "quick-blueprint-selected-button"
    end

    table.insert(event_list, function(event)
        if common.starts_with(event.element.name, INSERTER_BUTTON_NAME) then
            update_button_state_by_group(group, event.element.name)
            common.set_storage_value(player, savekey, common.get_selected_name(event.element.name, INSERTER_BUTTON_NAME))
            return true
        end
    end)
end

local function get_electric_poles()
    local poles = {}
    local pole_names = {
        "small-electric-pole",
        "small-iron-electric-pole",
        "medium-electric-pole"
    }
    for _, pole_name in ipairs(pole_names) do
        local pole = prototypes.entity[pole_name]
        if pole then
            table.insert(poles, pole)
        end
    end
    return poles
end

local function add_electric_pole_selector(player, frame)
    local parent = frame.add({
        type = "flow",
        direction = "vertical"
    })
    local label_row = parent.add({
        type = "flow",
        direction = "horizontal"
    })
    label_row.add({
        type = "label",
        caption = { "quick-blueprint.electric-pole" }
    })

    local pole_row = parent.add({
        type = "flow",
        direction = "horizontal"
    })

    local pole_list = get_electric_poles()
    local group = {}

    local savekey = common.savekeys.selected_electric_pole_name
    local saveval = common.get_storage_value(player, savekey)
    local check = false

    for i = 1, #pole_list do
        local pole = pole_list[i]

        if saveval and saveval == pole.name then
            check = true
            table.insert(group, pole_row.add({
                type = "sprite-button",
                name = ELECTRIC_POLE_BUTTON_NAME .. pole.name,
                sprite = "entity/" .. pole.name,
                tooltip = pole.localised_name or pole.name,
                style = "quick-blueprint-selected-button"
            }))
        else
            table.insert(group, pole_row.add({
                type = "sprite-button",
                name = ELECTRIC_POLE_BUTTON_NAME .. pole.name,
                sprite = "entity/" .. pole.name,
                tooltip = pole.localised_name or pole.name,
                style = "slot_button"
            }))
        end
    end

    if check == false then
        saveval = nil
    end
    if not saveval and pole_list[1] and group[1] then
        saveval = pole_list[1] and pole_list[1].name
        common.set_storage_value(player, savekey, saveval)
        group[1].style = "quick-blueprint-selected-button"
    end

    table.insert(event_list, function(event)
        if common.starts_with(event.element.name, ELECTRIC_POLE_BUTTON_NAME) then
            update_button_state_by_group(group, event.element.name)
            common.set_storage_value(player, savekey,
                common.get_selected_name(event.element.name, ELECTRIC_POLE_BUTTON_NAME))
            return true
        end
    end)
end

local function add_out_direction(player, frame)
    local parent = frame.add({
        type = "flow",
        direction = "vertical"
    })
    local label_row = parent.add({
        type = "flow",
        direction = "horizontal"
    })
    label_row.add({
        type = "label",
        caption = { "quick-blueprint.out-direction" }
    })
    local action_flow = parent.add {
        type = "flow",
        direction = "horizontal"
    }

    local left_button = action_flow.add {
        type = "sprite-button",
        name = DIRECTION_NAME .. "left",
        style = "slot_button",
        sprite = "utility/left_arrow",
        tooltip = { "quick-blueprint.move-left" }
    }

    local right_button = action_flow.add {
        type = "sprite-button",
        name = DIRECTION_NAME .. "right",
        style = "slot_button",
        sprite = "utility/right_arrow",
        tooltip = { "quick-blueprint.move-right" }
    }

    local group = { left_button, right_button }

    local savekey = common.savekeys.selected_direction
    local saveval = common.get_storage_value(player, savekey)
    if saveval == "right" then
        right_button.style = "quick-blueprint-selected-button"
    else
        left_button.style = "quick-blueprint-selected-button"
    end

    table.insert(event_list, function(event)
        if common.starts_with(event.element.name, DIRECTION_NAME) then
            update_button_state_by_group(group, event.element.name)
            common.set_storage_value(player, savekey, common.get_selected_name(event.element.name, DIRECTION_NAME))
            return true
        end
    end)
end

local COUNT_MODE_ONE = {
    name = "1",
    caption = { "quick-blueprint.count-1" },
    tooltip = { "quick-blueprint.count-1-tooltip" }
}
local COUNT_MODE_HALF = {
    name = "half",
    caption = { "quick-blueprint.count-half" },
    tooltip = { "quick-blueprint.count-half-tooltip" }
}
local COUNT_MODE_FULL = {
    name = "full",
    caption = { "quick-blueprint.count-full" },
    tooltip = { "quick-blueprint.count-full-tooltip" }
}
local COUNT_MODE_OUT_HALF = {
    name = "out-half",
    caption = { "quick-blueprint.count-out-half" },
    tooltip = { "quick-blueprint.count-out-half-tooltip" }
}
local COUNT_MODE_COST_FULL = {
    name = "cost-full",
    caption = { "quick-blueprint.count-cost-full" },
    tooltip = { "quick-blueprint.count-cost-full-tooltip" }
}

-- Which targets make sense depends on how the recipe's input cost compares to
-- its output, so this is the set each recipe type is narrowed to.
local COUNT_MODES_BY_RECIPE_TYPE = {
    [1] = { COUNT_MODE_ONE },
    out = { COUNT_MODE_ONE, COUNT_MODE_HALF, COUNT_MODE_FULL },
    cost = { COUNT_MODE_ONE, COUNT_MODE_COST_FULL },
    out_half = { COUNT_MODE_ONE, COUNT_MODE_OUT_HALF, COUNT_MODE_COST_FULL }
}
local DEFAULT_COUNT_MODE = {
    [1] = "1",
    out = "full",
    cost = "cost-full",
    out_half = "cost-full"
}

local function add_machine_count_selector(player, frame, recipe)
    local parent = frame.add({
        type = "flow",
        direction = "vertical"
    })
    local label_row = parent.add({
        type = "flow",
        direction = "horizontal"
    })
    label_row.add({
        type = "label",
        caption = { "quick-blueprint.machine-count" }
    })
    local action_flow = parent.add {
        type = "flow",
        direction = "horizontal"
    }

    -- The row is there from the start instead of appearing partway through a
    -- pick. Until there is a recipe only the targets that suit most recipes are
    -- offered - "output half" and "input full" mean nothing before the recipe's
    -- cost and output are known - and picking one narrows the row to the
    -- targets that recipe type supports.
    local recipe_type
    local options
    if recipe then
        recipe_type = myRecipe.get_recipe_cost_machine_type(recipe)
        options = COUNT_MODES_BY_RECIPE_TYPE[recipe_type] or COUNT_MODES_BY_RECIPE_TYPE[1]
    else
        options = COUNT_MODES_BY_RECIPE_TYPE.out
    end

    local savekey = common.savekeys.selected_count_mode
    local saveval = common.get_storage_value(player, savekey)
    local option_names = {}
    for _, opt in ipairs(options) do
        option_names[opt.name] = true
    end
    if not option_names[saveval] then
        saveval = DEFAULT_COUNT_MODE[recipe_type] or "1"
        -- Only a chosen recipe type has a default worth keeping. Without a
        -- recipe this row is a preview, and storing the fallback here would
        -- overwrite a preference that other recipe types do use.
        if recipe then
            common.set_storage_value(player, savekey, saveval)
        end
    end

    local group = {}
    for _, opt in ipairs(options) do
        local radio = action_flow.add {
            type = "radiobutton",
            name = COUNT_MODE_NAME .. opt.name,
            state = (saveval == opt.name),
            caption = opt.caption,
            tooltip = opt.tooltip
        }
        table.insert(group, radio)
    end

    table.insert(event_list, function(event)
        if common.starts_with(event.element.name, COUNT_MODE_NAME) then
            local selected_name = common.get_selected_name(event.element.name, COUNT_MODE_NAME)
            update_radiobutton_state_by_group(group, event.element.name)
            common.set_storage_value(player, savekey, selected_name)
            return true
        end
    end)
end

local function add_confirm_button(player, frame, recipe_name)
    local parent = frame.add({
        type = "flow",
        direction = "horizontal"
    })
    local button_row = parent.add({
        type = "flow",
        direction = "horizontal"
    })
    button_row.style.horizontally_stretchable = true
    button_row.style.top_padding = 30

    local spacer = button_row.add({
        type = "empty-widget"
    })
    spacer.style.horizontally_stretchable = true

    button_row.add({
        type = "sprite-button",
        name = CONFIRM_NAME,
        sprite = "utility/check_mark",
        tooltip = { "quick-blueprint.confirm-tooltip" },
        style = "confirm_button"
    })

    table.insert(event_list, function(event)
        if event.element.name == CONFIRM_NAME then
            if blueprint.set_blueprint(player, recipe_name) then
                return "control.close_all"
            end
            return true
        end
    end)
end

function self.init()
    event_list = {}
    table.insert(event_list, function(event)
        local element = event.element
        local module_name
        local is_add = common.starts_with(element.name, MODULE_ADD_PREFIX)
        if is_add then
            module_name = common.get_selected_name(element.name, MODULE_ADD_PREFIX)
        elseif common.starts_with(element.name, MODULE_REMOVE_PREFIX) then
            module_name = common.get_selected_name(element.name, MODULE_REMOVE_PREFIX)
        else
            return
        end
        local player = game.get_player(event.player_index)
        local frame = player and player.gui.screen[FRAME_NAME]
        local recipe_name = frame and frame.valid and frame.tags.recipe_name
        local recipe = recipe_name and myRecipe.get_recipe_by_name(recipe_name)
        if not player or not player.valid or not frame or not frame.valid or not recipe or not module_name then
            return
        end

        local machine_key = common.savekeys.selected_machine_name .. common.get_key(myRecipe.get_recipe_categories(recipe))
        local machine_name = common.get_storage_value(player, machine_key)
        local machine = machine_name and prototypes.entity[machine_name]
        if not machine_name or not machine then
            return
        end
        local slot_count = machine and machine.module_inventory_size or 0
        local available_modules = get_available_modules(machine)
        local selected_modules, used_slots = get_selected_modules(player, machine_name, available_modules, slot_count)

        if is_add and used_slots < slot_count then
            selected_modules[module_name] = (selected_modules[module_name] or 0) + 1
        elseif not is_add and selected_modules[module_name] then
            selected_modules[module_name] = selected_modules[module_name] - 1
            if selected_modules[module_name] == 0 then
                selected_modules[module_name] = nil
            end
        end

        local selections = common.get_storage_value(player, common.savekeys.selected_modules) or {}
        selections[machine_name] = selected_modules
        common.set_storage_value(player, common.savekeys.selected_modules, selections)
        local module_container = find_parent(element, MODULE_SELECTOR_CONTAINER_NAME)
        if not module_container or not module_container.valid then
            return
        end
        refresh_module_selector(player, module_container, recipe)
        return true
    end)
end

local function add_header(player, recipe_name)
    local frame = player.gui.screen.add({
        type = "frame",
        name = FRAME_NAME,
        direction = "vertical"
    })

    frame.tags = { recipe_name = recipe_name }

    frame.force_auto_center()

local header = frame.add({
        type = "flow",
        direction = "horizontal"
    })

    header.drag_target = frame

    header.add({
        type = "label",
        caption = { "quick-blueprint.config-title" },
        style = "frame_title" 
    })

    local drag_area = header.add({
        type = "empty-widget",
        style = "draggable_space_header"
    })
    drag_area.style.horizontally_stretchable = true
    drag_area.style.height = 24
    drag_area.drag_target = frame

    header.add({
        type = "sprite-button",
        name = CLOSE_NAME,
        sprite = "utility/close",
        tooltip = { "quick-blueprint.close" }
    })

    table.insert(event_list, function(event)
        if event.element.name == CLOSE_NAME then
            return self.close(event)
        end
    end)

    return frame
end

-- The recipe is chosen with the game's own recipe selector - the same dialog
-- the crafting menu and the item filter slots use - so it searches localized
-- and internal names, groups the recipes, and keeps its own list of recent
-- picks. Nothing here has to build a list or a filter.
local function add_recipe_selector(frame, recipe_name)
    local row = frame.add({
        type = "flow",
        direction = "horizontal"
    })
    row.style.vertical_align = "center"

    row.add({
        type = "label",
        caption = { "quick-blueprint.select-unlocked-recipe" }
    })

    local recipe_button = row.add({
        type = "choose-elem-button",
        name = RECIPE_BUTTON_NAME,
        elem_type = "recipe",
        recipe = recipe_name,
        elem_filters = myRecipe.get_recipe_elem_filters(),
        tooltip = { "quick-blueprint.select-recipe-tooltip" }
    })
    recipe_button.style.size = 40
end

-- One menu. The recipe picker is its first row and the choices that do not
-- depend on the recipe - belt, inserter, power, direction - are always there,
-- so the window reads the same before and after a pick. Only the rows that are
-- about the chosen recipe are filled in once there is one.
local function build_window_content(player, frame, recipe_name)
    local recipe = recipe_name and myRecipe.get_recipe_by_name(recipe_name)

    add_recipe_selector(frame, recipe_name)

    if recipe then
        local module_container = add_machine_selector(player, frame, recipe)
        refresh_module_selector(player, module_container, recipe)
    else
        frame.add({
            type = "label",
            caption = { "quick-blueprint.no-recipe-selected" }
        })
    end

    add_transport_belt_selector(player, frame)
    add_inserter_selector(player, frame)
    add_electric_pole_selector(player, frame)
    add_out_direction(player, frame)
    -- Built with no recipe too: it only needs the recipe for which targets to
    -- offer, and a row that vanishes is worse than one that offers all of them.
    add_machine_count_selector(player, frame, recipe)

    if recipe then
        add_confirm_button(player, frame, recipe_name)
    end
end

function self.open_gui(player, recipe_name)
    -- Picking a recipe rebuilds the frame, so carry the position over instead
    -- of snapping the window back to the middle of the screen mid-edit.
    local previous_location
    local existing = player.gui.screen[FRAME_NAME]
    if existing and existing.valid then
        previous_location = existing.location
        existing.destroy()
    end

    -- A remembered recipe can be gone after a mod update, and the picker would
    -- then draw nothing at all.
    if recipe_name and not myRecipe.get_recipe_by_name(recipe_name) then
        recipe_name = nil
    end

    self.init()
    local frame = add_header(player, recipe_name)
    build_window_content(player, frame, recipe_name)

    if previous_location then
        frame.auto_center = false
        frame.location = previous_location
    end

    -- Registering the frame is what makes Escape close the window.
    player.opened = frame
end

function self.open(event)
    local player = game.get_player(event.player_index)
    if not player or not player.valid then
        return
    end

    self.open_gui(player, common.get_storage_value(player, common.savekeys.selected_recipe_name))
end

function self.handle_elem_changed(event)
    local element = event.element
    if not element or not element.valid or element.name ~= RECIPE_BUTTON_NAME then
        return
    end

    local player = game.get_player(event.player_index)
    if not player or not player.valid then
        return
    end

    -- The picker is asked for unlocked recipes only. If a filter is ever not
    -- applied the way it is asked for, a locked recipe still gets refused here
    -- rather than silently reaching the blueprint generator.
    local recipe_name = element.elem_value
    if recipe_name then
        local recipe = myRecipe.get_recipe_by_name(recipe_name)
        if not recipe or not myRecipe.is_recipe_selectable(player, recipe) then
            player.print({ "quick-blueprint.recipe-not-available" })
            recipe_name = nil
        end
    end

    common.set_storage_value(player, common.savekeys.selected_recipe_name, recipe_name)
    self.open_gui(player, recipe_name)
    return true
end

function self.is_frame(element)
    return element and element.valid and element.name == FRAME_NAME
end

function self.handle_click(event)
    local element = event.element

    for i = 1, #event_list do
        local eventfun = event_list[i]
        local result = eventfun(event)
        if result then
            return result
        end
    end
end

function self.close(event)
    local player = game.get_player(event.player_index)
    if not player or not player.valid then
        return
    end
    local frame = player.gui.screen[FRAME_NAME]
    if frame and frame.valid then
        frame.destroy()
        return true
    end
end

return self
