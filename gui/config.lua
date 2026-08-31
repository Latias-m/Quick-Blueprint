local common = require("common")
local myRecipe = require("recipe.recipe")
local blueprint = require("blueprint.blueprint")
local self = {}
local START_NAME = common.MOD_NAME .. "-config-"
local FRAME_NAME = START_NAME .. "-gui"
local CLOSE_NAME = START_NAME .. "-close-button-"
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

    local recipe_type = myRecipe.get_recipe_cost_machine_type(recipe)
    local options_by_recipe_type = {
        [1] = {
            { name = "1", caption = { "quick-blueprint.count-1" }, tooltip = { "quick-blueprint.count-1-tooltip" } },
        },
        out = {
            { name = "1", caption = { "quick-blueprint.count-1" }, tooltip = { "quick-blueprint.count-1-tooltip" } },
            { name = "half", caption = { "quick-blueprint.count-half" }, tooltip = { "quick-blueprint.count-half-tooltip" } },
            { name = "full", caption = { "quick-blueprint.count-full" }, tooltip = { "quick-blueprint.count-full-tooltip" } },
        },
        cost = {
            { name = "1", caption = { "quick-blueprint.count-1" }, tooltip = { "quick-blueprint.count-1-tooltip" } },
            { name = "cost-full", caption = { "quick-blueprint.count-cost-full" }, tooltip = { "quick-blueprint.count-cost-full-tooltip" } },
        },
        out_half = {
            { name = "1", caption = { "quick-blueprint.count-1" }, tooltip = { "quick-blueprint.count-1-tooltip" } },
            { name = "out-half", caption = { "quick-blueprint.count-out-half" }, tooltip = { "quick-blueprint.count-out-half-tooltip" } },
            { name = "cost-full", caption = { "quick-blueprint.count-cost-full" }, tooltip = { "quick-blueprint.count-cost-full-tooltip" } },
        },
    }
    local options = options_by_recipe_type[recipe_type] or options_by_recipe_type[1]

    local savekey = common.savekeys.selected_count_mode
    local saveval = common.get_storage_value(player, savekey)
    local option_names = {}
    for _, opt in ipairs(options) do
        option_names[opt.name] = true
    end
    if not option_names[saveval] then
        local default_count_modes = {
            [1] = "1",
            out = "full",
            cost = "cost-full",
            out_half = "cost-full"
        }
        saveval = default_count_modes[recipe_type] or "1"
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

    common.set_storage_value(player, savekey, saveval)
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

function self.open_gui(player, recipe_name)
    local existing = player.gui.screen[FRAME_NAME]
    if existing and existing.valid then
        existing.destroy()
    end

    self.init()
    local frame = add_header(player, recipe_name)
    local recipe = myRecipe.get_recipe_by_name(recipe_name)
    if not recipe then
        log("[Quick Blueprint] Configuration window could not be opened: recipe not found: " .. tostring(recipe_name))
        frame.destroy()
        player.print({ "quick-blueprint.blueprint-generation-failed" })
        return
    end
    local module_container = add_machine_selector(player, frame, recipe)
    refresh_module_selector(player, module_container, recipe)
    add_transport_belt_selector(player, frame)
    add_inserter_selector(player, frame)
    add_electric_pole_selector(player, frame)
    add_out_direction(player, frame)
    add_machine_count_selector(player, frame, recipe)
    add_confirm_button(player, frame, recipe_name)
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
