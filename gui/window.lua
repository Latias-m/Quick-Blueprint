local myRecipe = require("recipe.recipe")
local common = require("common")
local config = require("gui.config")
local self = {}

local MOD_NAME = common.MOD_NAME
local START_NAME = MOD_NAME .. "-window-"
local FRAME_NAME = START_NAME .. "-gui"
local FRAME_RECIPE_NAME = START_NAME .. "-recipe-gui"
local CLOSE_NAME = START_NAME .. "-close-button"
local RECIPE_PREFIX = START_NAME .. "-recipe-"
local FILTER_PREFIX = START_NAME .. "-filter-"
local FILTER_TEXTFIELD_NAME = START_NAME .. "-textfield"
local FILTER_APPLY_BUTTON_NAME = START_NAME .. "-apply-button"

local function get_state()
  storage.quick_blueprint_state = storage.quick_blueprint_state or {}
  return storage.quick_blueprint_state
end

local function get_player_state(player)
  local state = get_state()
  state[player.index] = state[player.index] or { selected_group = "" }
  return state[player.index]
end

local function get_recipe_name_from_button(element)
  if not element.name or string.sub(element.name, 1, #RECIPE_PREFIX) ~= RECIPE_PREFIX then
    return nil
  end
  return string.sub(element.name, #RECIPE_PREFIX + 1)
end

local function get_filter_name_from_button(element)
  if not element.name or string.sub(element.name, 1, #FILTER_PREFIX) ~= FILTER_PREFIX then
    return nil
  end
  return string.sub(element.name, #FILTER_PREFIX + 1)
end

local function update_filter_button(player, selected_subgroup)
  self.bar.clear()
  local grouplist = myRecipe.get_unlocked_recipes(player)
  for _, group in ipairs(grouplist) do
    local button = self.bar.add({
      type = "sprite-button",
      name = FILTER_PREFIX .. group._self.name,
      sprite = "item-group/" .. group._self.name,
      tooltip = group._self.localised_name
    })
    button.style.size = 80
  end

  local state = get_player_state(player)
  state.selected_group = selected_subgroup or (grouplist[1] and grouplist[1]._self.name)
end

local function build_filter_bar(frame, player, selected_subgroup)
  local parent = frame.add({
    type = "flow",
    direction = "vertical"
  })

  local filter_row = parent.add({
    type = "flow",
    direction = "horizontal"
  })
  filter_row.style.vertical_align = "center"

  filter_row.add({
    type = "label",
    caption = { "quick-blueprint.filter" }
  })

  self.textfield = filter_row.add({
    type = "textfield",
    name = FILTER_TEXTFIELD_NAME
  })

  filter_row.add({
    type = "button",
    name = FILTER_APPLY_BUTTON_NAME,
    caption = { "quick-blueprint.apply" },
    style = "button"
  })

  myRecipe.clear_filter()

  self.bar = parent.add({
    type = "table",
    column_count = 10,
  })

  update_filter_button(player, selected_subgroup)
  return
end

local function add_subgroup_recipe(subgroup_list, parent)
  for index, value in ipairs(subgroup_list) do
    local row = parent.add({
      type = "table",
      column_count = 10,
    })

    for _, recipe in ipairs(value.recipes) do
      row.add({
        type = "sprite-button",
        name = RECIPE_PREFIX .. recipe.name,
        sprite = "recipe/" .. recipe.name,
        tooltip = myRecipe.build_recipe_tooltip(recipe)
      })
    end
  end
end

local function update_recipe_list(player)
  local state = get_player_state(player)
  local parentframe = player.gui.screen[FRAME_NAME]

  if parentframe and parentframe.valid then
    local frame = parentframe[FRAME_RECIPE_NAME]

    if frame and frame.valid then
      frame.clear()

      local scroll = frame.add({
        type = "scroll-pane",
        vertical_scroll_policy = "auto",
        horizontal_scroll_policy = "never",

      })
      scroll.style.maximal_height = 360

      local group_list = myRecipe.get_group_recipes()

      for index, value in ipairs(group_list) do
        if (value._self.name == state.selected_group) then
          add_subgroup_recipe(value.subgroups, scroll)
          break
        end
      end
    end
  end
  return get_player_state(player)
end

local function set_header(player)
  local frame = player.gui.screen.add({
    type = "frame",
    name = FRAME_NAME,
    direction = "vertical"
  })

  player.opened = frame

  frame.force_auto_center()

  frame.style.minimal_height = 520
  frame.style.maximal_height = 520

local header = frame.add({
    type = "flow",
    direction = "horizontal"
  })
  header.drag_target = frame
  header.add({
    type = "label",
    caption = { "quick-blueprint.mod-title" },
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

  return frame
end

local function build_window(player)
  local existing = player.gui.screen[FRAME_NAME]
  if existing and existing.valid then
    existing.destroy()
  end

  local state = get_player_state(player)

  local frame = set_header(player)

build_filter_bar(frame, player, state.selected_subgroup)
  frame.add({
    type = "flow",
    direction = "vertical",
    name = FRAME_RECIPE_NAME
  })

update_recipe_list(player)
end

local function filter_apply(player)
  local filter_text = self.textfield.text
  if filter_text and filter_text ~= "" then
    myRecipe.set_filter(filter_text)
  else
    myRecipe.clear_filter()
  end

  update_filter_button(player, get_player_state(player).selected_group)
  update_recipe_list(player)
end

function self.open(event)
  local player = game.get_player(event.player_index)
  if not player or not player.valid then
    return
  end

  build_window(player)
end

function self.close(event)
  local player = game.get_player(event.player_index)
  if not player or not player.valid then
    return
  end
  local frame = player.gui.screen[FRAME_NAME]
  if frame and frame.valid then
    frame.destroy()
  end
end

function self.is_close_button(element)
  return element and element.valid and element.name == CLOSE_NAME
end

function self.is_window(element)
  return element and element.valid and element.name == FRAME_NAME
end

function self.is_filter_apply(element)
  return element and element.valid and element.name == FILTER_APPLY_BUTTON_NAME
end

function self.handle_click(event)
  local element = event.element
  if common.starts_with(element.name, START_NAME) then
    local player = game.get_player(event.player_index)

    local filter_name = get_filter_name_from_button(element)
    if filter_name then
      local state = get_player_state(player)
      state.selected_group = filter_name
      update_recipe_list(player)
      return true
    end

    local recipe_name = get_recipe_name_from_button(element)
    if recipe_name then
      config.open_gui(player, recipe_name)
      return true
    end

    if self.is_close_button(element) then
      self.close(event)
      return true
    end

    if self.is_filter_apply(element) then
      filter_apply(player)
      return true
    end
  end
  return false
end

return self
