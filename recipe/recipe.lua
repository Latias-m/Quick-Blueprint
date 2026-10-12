local myRecipe = {}
local EXCLUDED_RECIPE_CATEGORIES = {
    ["transport-drone-request"] = true,
    ["transport-fluid-request"] = true,
    ["parameters"] = true
}

local recipe_elem_filters

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

-- Whether the player may pick this recipe at all: it has to be unlocked for
-- their force, must not be hidden, and must not be one of the pseudo-crafting
-- categories that never describe a production line.
function myRecipe.is_recipe_selectable(player, recipe)
    if not recipe or recipe.hidden or not is_recipe_unlocked(player, recipe.name) then
        return false
    end

    for _, category in ipairs(myRecipe.get_recipe_categories(recipe)) do
        if EXCLUDED_RECIPE_CATEGORIES[category] then
            return false
        end
    end

    return true
end

-- The filters handed to the game's own recipe picker.
--
-- Only "hidden" is asked for. A "category" filter with `invert` would drop the
-- request/parameter pseudo-recipes too, and an "enabled" filter would be the
-- obvious way to ask for just the unlocked ones - but "enabled" is read from
-- the prototype's own pre-research default rather than from the player's
-- force, so it hides everything that any technology unlocks. Recipe
-- availability is therefore decided in Lua, by is_recipe_selectable, on the
-- pick as well as here.
function myRecipe.get_recipe_elem_filters()
    if not recipe_elem_filters then
        recipe_elem_filters = {
            { filter = "hidden", invert = true }
        }
    end

    return recipe_elem_filters
end

function myRecipe.get_recipe_by_name(recipe_name)
    return prototypes.recipe[recipe_name]
end

return myRecipe
