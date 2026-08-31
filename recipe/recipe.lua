local myRecipe = {}
local common = require("common")
local EXCLUDED_RECIPE_CATEGORIES = {
    ["transport-drone-request"] = true,
    ["transport-fluid-request"] = true,
    ["parameters"] = true
}

local filter = nil
local grouped_recipes_cache = {}

local function safe_get(value, key)
    if value == nil then
        return nil
    end
    local ok, result = pcall(function()
        return value[key]
    end)
    if ok then
        return result
    end
    return nil
end

local function is_excluded_recipe(player, recipe)
    local categories = myRecipe.get_recipe_categories(recipe)
    for _, category in ipairs(categories) do
        if EXCLUDED_RECIPE_CATEGORIES[category] then
            return true
        end
    end

    if filter and filter ~= "" then
        local recipe_name_list = common.get_storage_value(player, common.savekeys.recipe_name_list) or {}
        local recipe_name = safe_get(recipe, "name")
        local local_name = recipe_name_list[recipe_name]
        return not (local_name and string.find(string.lower(local_name), string.lower(filter), 1, true) ~= nil)
    end

    return false
end
local function get_belt_throughput(belt_name)
    local proto = prototypes.entity[belt_name]
    if not proto or not proto.belt_speed then
        return 60
    end
    local total_throughput = proto.belt_speed * 480

    return total_throughput
end

function myRecipe.get_machine_count(recipt, machine_name, transport_belt, modules)
    local ingredients = recipt.ingredients or {}
    local count_item = 0
    local max_use = 0
    for _, ingredient in ipairs(ingredients) do
        if ingredient.type == "fluid" then
        elseif ingredient.type == "item" then
            count_item = count_item + 1
            if ingredient.amount > max_use then
                max_use = ingredient.amount
            end
        end
    end

    local products = recipt.products or {}
    local amount = 0
    for _, product in ipairs(products) do
        if product.type == "item" then
            amount = amount + product.amount
        end
    end
    local crafting_time = safe_get(recipt, "energy")
        or safe_get(recipt, "energy_required")
        or 0.5

    local crafting_speed = 1.0

    if machine_name then
        local machine_proto = prototypes.entity[machine_name]

        if machine_proto and machine_proto.get_crafting_speed then
            crafting_speed = machine_proto.get_crafting_speed("normal") or 1.0
        end
    end
    local speed_bonus = 0
    for module_name, count in pairs(modules or {}) do
        local module = prototypes.item[module_name]
        local speed = module and module.module_effects and module.module_effects.speed
        if type(speed) == "table" then
            speed = speed.bonus
        end
        if type(speed) == "number" and type(count) == "number" then
            speed_bonus = speed_bonus + speed * count
        end
    end
    crafting_speed = crafting_speed * (1 + speed_bonus)
    local do_times = (1 / crafting_time) * crafting_speed
    local use_amount_per_second = max_use * do_times
    local out_amount_per_second = amount * do_times

    local total_throughput = get_belt_throughput(transport_belt)
    local cost = total_throughput
    if count_item > 5 then
        cost = total_throughput / 2
    end

    local cost_machine = (use_amount_per_second > 0) and math.ceil(cost / use_amount_per_second) or 0
    local out_machine_full = (out_amount_per_second > 0) and math.ceil(total_throughput / out_amount_per_second) or 0

    return cost_machine, out_machine_full
end

function myRecipe.get_recipe_cost_machine_type(recipe)
    local cost_machine, out_machine_full = myRecipe.get_machine_count(recipe)
    if cost_machine > 0 or out_machine_full > 0 then
        if cost_machine < out_machine_full and cost_machine > 0 then
            if cost_machine > out_machine_full / 2 then
                return "out_half"
            end

            return "cost"
        else
            return "out"
        end
    else
        return 1
    end
end

function myRecipe.get_recipe_categories(recipe)
    local categories = safe_get(recipe, "categories")
    if type(categories) == "table" and next(categories) ~= nil then
        return categories
    end

    local category = safe_get(recipe, "category")
    if category and category ~= "" then
        return { category }
    end

    return { "crafting" }
end

function myRecipe.get_allowed_machines_for_recipe(recipe)
    local categories = myRecipe.get_recipe_categories(recipe)
    local machines = {}

    for _, prototype in pairs(prototypes.entity) do
        if prototype and prototype.type and prototype.crafting_categories then
            local ok = false

            for _, category in pairs(categories) do
                if prototype.crafting_categories[category] == true and prototype.type ~= "character" then
                    ok = true
                    break
                end
            end

            if ok then
                machines[#machines + 1] = prototype
            end
        end
    end

    return machines
end

local function is_recipe_unlocked(player, recipe_name)
    if not player or not player.valid then
        return false
    end
    local force_recipe = player.force and player.force.recipes and player.force.recipes[recipe_name]
    return force_recipe and force_recipe.enabled
end
local function spairs(t, order)
    if order == nil then return pairs(t) end
    local keys = {}
    for k in pairs(t) do keys[#keys + 1] = k end
    pcall(function()
        table.sort(keys, function(a, b) return order(t, a, b) end)
    end)
    local i = 0
    return function()
        i = i + 1
        if keys[i] then
            return keys[i], t[keys[i]]
        end
    end
end

function myRecipe.get_unlocked_recipes(player)
    if not player or not player.valid then
        return {}
    end

    grouped_recipes_cache = {}

    local group_info = {}
    local subgroup_info = {}
    for name, recipe in pairs(prototypes.recipe) do
        if recipe and recipe.name and is_recipe_unlocked(player, name) and not recipe.hidden and not is_excluded_recipe(player, recipe) then
            if grouped_recipes_cache[recipe.group.name] == nil then
                grouped_recipes_cache[recipe.group.name] = {}
                group_info[recipe.group.name] = recipe.group
            end
            if grouped_recipes_cache[recipe.group.name][recipe.subgroup.name] == nil then
                grouped_recipes_cache[recipe.group.name][recipe.subgroup.name] = {}
            end
            subgroup_info[recipe.subgroup.name] = recipe.subgroup

            table.insert(grouped_recipes_cache[recipe.group.name][recipe.subgroup.name], recipe)
        end
    end

    local sorted_groups = {}

    for group_name, subgroup_map in spairs(grouped_recipes_cache, function(t, a, b)
        return group_info[a].order < group_info[b].order
    end) do
        local sorted_subgroups = {}

        for subgroup_name, recipes in spairs(subgroup_map, function(t, a, b)
            return subgroup_info[a].order < subgroup_info[b].order
        end) do
            sorted_subgroups[#sorted_subgroups + 1] = {
                name = subgroup_name,
                recipes = recipes,
                _self = subgroup_info[subgroup_name]
            }
        end

        sorted_groups[#sorted_groups + 1] = {
            name = group_name,
            subgroups = sorted_subgroups,
            _self = group_info[group_name]
        }
    end

    grouped_recipes_cache = sorted_groups

    return grouped_recipes_cache
end

function myRecipe.get_group_recipes()
    if not grouped_recipes_cache then
        return {}
    end
    return grouped_recipes_cache
end

local function get_icon_markup(prototype_name, prototype_type)
    if not prototype_name or not prototype_type then
        return ""
    end

    if prototype_type == "fluid" then
        return "[img=fluid/" .. prototype_name .. "]"
    elseif prototype_type == "item" then
        return "[img=item/" .. prototype_name .. "]"
    elseif prototype_type == "entity" then
        return "[entity=" .. prototype_name .. "]"
    elseif prototype_type == "recipe" then
        return "[recipe=" .. prototype_name .. "]"
    elseif prototype_type == "technology" then
        return "[technology=" .. prototype_name .. "]"
    end

    return ""
end

function myRecipe.build_recipe_tooltip(recipe)
    if not recipe then
        return { "" }
    end

    local tooltip = { "" }
    local recipe_name = safe_get(recipe, "localised_name") or safe_get(recipe, "name") or "Unknown recipe"
    table.insert(tooltip, { "", "[font=default-bold]", recipe_name, "[/font]" })
    local ingredients = safe_get(recipe, "ingredients") or {}
    if #ingredients > 0 then
        table.insert(tooltip, { "", "\n", "[font=default-bold]", { "quick-blueprint.ingredients" }, "[/font]" })
        for _, ingredient in ipairs(ingredients) do
            local ingredient_name = ingredient.name
            local ingredient_type = ingredient.type or "item"
            local ingredient_proto = prototypes[ingredient_type] and prototypes[ingredient_type][ingredient_name]
            local ingredient_label = ingredient_proto and (ingredient_proto.localised_name or ingredient_name) or
                ingredient_name

            table.insert(tooltip, {
                "",
                "\n",
                get_icon_markup(ingredient_name, ingredient_type),
                ingredient_label,
                " x ",
                tostring(ingredient.amount or 1)
            })
        end
    end
    local crafting_time = safe_get(recipe, "energy")
        or safe_get(recipe, "energy_required")
        or 0.5
    table.insert(tooltip,
        { "", "\n", "[font=default-bold]", { "quick-blueprint.crafting-time" }, "[/font]", " ", tostring(crafting_time),
            " s" })
    local machines = myRecipe.get_allowed_machines_for_recipe(recipe)

    if #machines > 0 then
        table.insert(tooltip, { "", "\n", "[font=default-bold]", { "quick-blueprint.crafted-at" }, "[/font]" })
        for i = 1, math.min(5, #machines) do
            local machine = machines[i]
            local machine_name = machine.localised_name or machine.name
            table.insert(tooltip, {
                "",
                "\n",
                "[entity=" .. machine.name .. "] ",
                machine_name
            })
        end
    end

    return tooltip
end

function myRecipe.set_filter(str)
    filter = str
end

function myRecipe.clear_filter()
    filter = nil
end

function myRecipe.get_recipe_by_name(recipe_name)
    return prototypes.recipe[recipe_name]
end

return myRecipe
