filesize = require("scripts/filesize")

--- @class PlayerTable
--- @field start_of_selection MapPosition?
--- @field end_of_selection MapPosition?
--- @field tool_in_progress boolean
--- @field map_view_during_tool_use boolean
--- @field filesize_parameter float
--- @field zoom_index uint

local max_resolution = 16384 -- Factorio limit
local max_resolution_anti_alias = max_resolution / 2
local min_zoom_level = 0.03125 -- Factorio limit
local max_zoom_level = 8
---@type float[]|string[]
local zoom_levels = {"auto", 0.03125, 0.0625, 0.125, 0.25, 0.5, 1, 2, 4, 8}

--- @param player_index uint
local function player_init(player_index)
  storage.players[player_index] = {
    start_of_selection = nil,
    end_of_selection = nil,
    tool_in_progress = false,
    map_view_during_tool_use = false,
    filesize_parameter = get_filesize_parameter(player_index),
    zoom_index = 1,
  }
end

-- Modified from flib
local function format_time(tick)
  local total_seconds = math.floor((tick or game.ticks_played) / 60)
  local seconds = total_seconds % 60
  local minutes = math.floor(total_seconds / 60) % 60
  local hours = math.floor(total_seconds / 3600)
  return string.format("%04dh%02dm%02ss", hours, minutes, seconds)
end

local function is_holding_tool(cursor_stack)
  return cursor_stack ~= nil and cursor_stack.valid_for_read and  cursor_stack.name == "sas-snipping-tool"
end

--- @param pos1 MapPosition
--- @param pos2 MapPosition
--- @param zoom float
local function get_dimensions_from_box(pos1, pos2, zoom)
  local width = math.abs(pos1.x - pos2.x)
  local height = math.abs(pos1.y - pos2.y)
	local resX = math.floor(width * 32 * zoom)
	local resY = math.floor(height * 32 * zoom)
	local centerX = math.min(pos1.x, pos2.x) + width / 2
	local centerY = math.min(pos1.y, pos2.y) + height / 2
  return {
    size = {x=width, y=height},
    resolution = {x=resX, y=resY},
    center = {x=centerX, y=centerY},
  }
end

---@return float zoom_level
local function get_auto_zoom_level(pos1, pos2, auto_zoom_target_res)
  local width = math.abs(pos1.x - pos2.x)
  local height = math.abs(pos1.y - pos2.y)
  local largest_side_px = math.max(width, height) * 32
  local zoom_level = auto_zoom_target_res / largest_side_px

  if zoom_level > max_zoom_level then
    zoom_level = max_zoom_level
  elseif zoom_level < min_zoom_level then
    zoom_level = min_zoom_level
  end

  return zoom_level
end

local function get_displayed_zoom_level(zoom_level)
  if zoom_level == "auto" then
    return "Auto"
  end
  if zoom_level >= 1 then
    return string.format("x%.2g", zoom_level)
  else
    return string.format("x1/%d", math.ceil(1 / zoom_level))
  end
end

local function update_cursor_label(player_index, player_table, cursor_stack)
  if not (cursor_stack.valid and cursor_stack.valid_for_read) then return end
  local display_zoom

  local sel_start = player_table.start_of_selection
  local sel_end = player_table.end_of_selection
  if player_table.map_view_during_tool_use or sel_start == nil or (sel_start.x == sel_end.x and sel_start.y == sel_end.y) then
    display_zoom = get_displayed_zoom_level(zoom_levels[player_table.zoom_index])
    cursor_stack.label = string.format("Zoom: %s", display_zoom)
  else
    local zoom_level = zoom_levels[player_table.zoom_index]
    if zoom_level == "auto" then
      local auto_zoom_target_res = settings.get_player_settings(player_index)["sas-autozoom-target-px"].value
      zoom_level = get_auto_zoom_level(sel_start, sel_end, auto_zoom_target_res)
      display_zoom = string.format("Auto (%s)", get_displayed_zoom_level(zoom_level))
    else
      display_zoom = get_displayed_zoom_level(zoom_levels[player_table.zoom_index])
    end
    ---@cast zoom_level float
    local dimensions = get_dimensions_from_box(sel_start, sel_end, zoom_level)
    local pixel_count = dimensions.resolution.x * dimensions.resolution.y

    local label = string.format("Zoom: %s | %sx%spx (%s)",
      display_zoom, dimensions.resolution.x, dimensions.resolution.y, get_filesize_string(player_table, pixel_count))

    local largest_side = math.max(dimensions.resolution.x, dimensions.resolution.y)
    if largest_side > max_resolution then
      label = "[color=red]" .. label .. " | ⚠TOO BIG![/color]"
    elseif largest_side > max_resolution_anti_alias then
      local anti_alias = settings.get_player_settings(player_index)["sas-anti-alias"].value --[[@as boolean]]
      if anti_alias then
        label = "[color=yellow]" .. label .. " | ⚠Anti-alias disabled[/color]"
      end
    end

    cursor_stack.label = label
  end
end

local function update_zoom(player_index, direction)
  local player_table = storage.players[player_index]
  if not player_table then return end
  if not player_table.tool_in_progress then return end -- Only allow this shortcut when holding the tool

  local new_zoom_index
  if player_table.zoom_index == 1 and player_table.start_of_selection then -- Auto in progress
    local sel_start = player_table.start_of_selection
    local sel_end = player_table.end_of_selection
    local auto_zoom_target_res = settings.get_player_settings(player_index)["sas-autozoom-target-px"].value
    current_zoom_level = get_auto_zoom_level(sel_start, sel_end, auto_zoom_target_res)

    if direction == 1 then new_zoom_index = 2 else new_zoom_index = #zoom_levels end
    while 2 <= new_zoom_index and new_zoom_index <= #zoom_levels do
      zoom_level = zoom_levels[new_zoom_index]
      if (direction == 1 and zoom_level > current_zoom_level) or
         (direction == -1 and zoom_level < current_zoom_level) then
        break
      end
      new_zoom_index = new_zoom_index + direction
    end
  else
    new_zoom_index = player_table.zoom_index + direction
  end
  if new_zoom_index <= 0 or #zoom_levels < new_zoom_index then return end

  player_table.zoom_index = new_zoom_index
  local player = game.get_player(player_index) --[[@as LuaPlayer]]
  local cursor_stack = player.cursor_stack
  if cursor_stack == nil then
    return
  end
  update_cursor_label(player_index, player_table, cursor_stack)
end


script.on_init(function()
  --- @type table<uint, PlayerTable>
  storage.players = {}

  for _, player in pairs(game.players) do
    player_init(player.index)
  end
end)

script.on_event(defines.events.on_player_created, function(e)
  player_init(e.player_index)
end)

script.on_event(defines.events.on_runtime_mod_setting_changed, function(e)
  if e.setting == "sas-filetype" or e.setting == "sas-jpg-quality" then
    storage.players[e.player_index].filesize_parameter = get_filesize_parameter(e.player_index)
  end
end)

script.on_event(defines.events.on_player_cursor_stack_changed, function(e)
  local player = game.get_player(e.player_index) --[[@as LuaPlayer]]
  local player_table = storage.players[e.player_index]
  if not player_table then
    return
  end
  local cursor_stack = player.cursor_stack
  local holding_tool = is_holding_tool(cursor_stack)
  if player_table.tool_in_progress then
    if not holding_tool then
      -- Tool use ended
      -- log("TOOL USE ENDED")
      player_table.tool_in_progress = false
      player_table.map_view_during_tool_use = false
      player_table.start_of_selection = nil
      player_table.end_of_selection = nil
      if player.character ~= nil then -- Protect against editor mode crashes
        local build_distance_bonus = player.character_build_distance_bonus
        if build_distance_bonus >= 1000000 then -- Safety check against mods who might have reduced it in the meantime.
          player.character_build_distance_bonus = build_distance_bonus - 1000000
        end
      end
    end
  else
    if holding_tool then
      -- Tool use started
      -- log("TOOL USE STARTED")
      player_table.tool_in_progress = true
      player_table.map_view_during_tool_use = player.render_mode == defines.render_mode.chart
      -- TODO: Check this works with disconnected players (hold tool, disconnect, reconnect, do you get infinite build range?)
      if player.character ~= nil then -- Protect against editor mode crashes
        player.character_build_distance_bonus = player.character_build_distance_bonus + 1000000
      end
      if settings.get_player_settings(player)["sas-autozoom-always-start"].value then
        player_table.zoom_index = 1
      end
      update_cursor_label(e.player_index, player_table, cursor_stack)
    end
  end
end)

-- Detect map view (which prevents placing item and breaks the label)
script.on_nth_tick(5, function(e)
  -- Spread the load? Probably not worth the init cost
  for player_index, player_table in pairs(storage.players) do
    if player_table.tool_in_progress and not player_table.map_view_during_tool_use then
      local player = game.get_player(player_index) --[[@as LuaPlayer]]
      if player.render_mode == defines.render_mode.chart then
        -- log("MAP VIEW WAS USED")
        player_table.map_view_during_tool_use = true
        update_cursor_label(player_index, player_table, player.cursor_stack)
      end
    end
  end
end)

-- Resets label when pressing Q while holding tool
script.on_event("sas-clear-cursor", function(e)
  local player_table = storage.players[e.player_index]
  if player_table.tool_in_progress then
    local player = game.get_player(e.player_index) --[[@as LuaPlayer]]
    local cursor_stack = player.cursor_stack
    if is_holding_tool(cursor_stack) then
      player_table.start_of_selection = nil
      player_table.end_of_selection = nil
      player_table.map_view_during_tool_use = false
      update_cursor_label(e.player_index, player_table, cursor_stack)
    end
  end
end)

script.on_event(defines.events.on_built_entity, function(e)
  local player = game.get_player(e.player_index) --[[@as LuaPlayer]]
  local player_table = storage.players[e.player_index]
  local entity = e.entity

  -- Cursor item will have been used to "place" the dummy, restore it.
  local cursor_stack = player.cursor_stack
  if cursor_stack == nil then
    return
  end
  cursor_stack.set_stack({ name = "sas-snipping-tool", count = 1 })

  if player_table.start_of_selection == nil then -- New selection
    player_table.start_of_selection = entity.position
  end
  player_table.end_of_selection = entity.position
  update_cursor_label(e.player_index, player_table, cursor_stack)

  entity.destroy()
end, {
  { filter = "name", name = "sas-dummy-entity" },
  { filter = "ghost_name", name = "sas-dummy-entity" },
})

script.on_event("sas-increase-zoom", function(e)
  update_zoom(e.player_index, 1)
end)
script.on_event("sas-decrease-zoom", function(e)
  update_zoom(e.player_index, -1)
end)

local function on_area_selected(e)
  -- log("PLACED: " .. serpent.line(e.area))
  local player = game.get_player(e.player_index) --[[@as LuaPlayer]]
  local player_table = storage.players[e.player_index]
  local cursor_stack = player.cursor_stack
  if not is_holding_tool(cursor_stack) then
    return
  end
  ---@cast cursor_stack -?
  cursor_stack.clear()
  player_table.start_of_selection = nil
  player_table.end_of_selection = nil

  local player_settings = settings.get_player_settings(player)

  local zoom_level = zoom_levels[player_table.zoom_index]
  if zoom_level == "auto" then
    local auto_zoom_target_res = player_settings["sas-autozoom-target-px"].value
    zoom_level = get_auto_zoom_level(e.area.left_top, e.area.right_bottom, auto_zoom_target_res)
    log("Auto zoom level: " .. zoom_level)
  end
  ---@cast zoom_level float

  local dimensions = get_dimensions_from_box(e.area.left_top, e.area.right_bottom, zoom_level)

  if dimensions.resolution.x <= 0 or dimensions.resolution.y <= 0 then
    return -- Silently abort
  end

  local anti_alias = player_settings["sas-anti-alias"].value --[[@as boolean]]
  local alt_mode = player_settings["sas-alt-mode"].value --[[@as boolean]]
  local hide_clouds_and_fog = player_settings["sas-hide-clouds-and-fog"].value --[[@as boolean]]

  local largest_side = math.max(dimensions.resolution.x, dimensions.resolution.y)
  local message
  if anti_alias and largest_side > max_resolution_anti_alias then
    anti_alias = false
    message = {"simple-area-screenshots.screenshot-too-big-anti-alias-disabled", max_resolution_anti_alias}
  end
  if largest_side > max_resolution then
    message = {"simple-area-screenshots.screenshot-too-big", max_resolution}
    dimensions.resolution.x = math.min(dimensions.resolution.x, max_resolution)
    dimensions.resolution.y = math.min(dimensions.resolution.y, max_resolution)
  end
  if message then
    player.print(message, {game_state=false})
  end

  local file_extension
  local jpg_quality
  if player_settings["sas-filetype"].value == "JPEG" then
    file_extension = "jpg"
    jpg_quality = player_settings["sas-jpg-quality"].value --[[@as uint]]
  elseif player_settings["sas-filetype"].value == "PNG" then
    file_extension = "png"
  else
    error("Unknown file type: " .. player_settings["sas-filetype"].value)
  end

  local daytime
  local also_nighttime = false
  if player_settings["sas-daytime"].value == "daytime" then
    daytime = 0
  elseif player_settings["sas-daytime"].value == "nighttime" then
    daytime = 0.5
  elseif player_settings["sas-daytime"].value == "both" then
    daytime = 0
    also_nighttime = true
  end

  local game_id = game.default_map_gen_settings.seed % 10000 -- First 4 digits
  local filename = string.format("%s_%s_%s.%s", game_id, format_time(e.tick), e.surface.name, file_extension)
  local full_path = "simple-area-screenshots/" .. filename

	game.take_screenshot({
		by_player = e.player_index,
		surface = e.surface,
		position = dimensions.center,
		resolution = dimensions.resolution,
		zoom = zoom_level,
    path = full_path,
    show_entity_info = alt_mode,
    anti_alias = anti_alias,
    hide_clouds = hide_clouds_and_fog,
    hide_fog = hide_clouds_and_fog,
    quality = jpg_quality,
		daytime = daytime,
	})

  if also_nighttime then
    local night_filename = string.format("%s_%s_%s_night.%s", game_id, format_time(e.tick), e.surface.name, file_extension)
    local night_full_path = "simple-area-screenshots/" .. night_filename
    game.take_screenshot({
      by_player = e.player_index,
      surface = e.surface,
      position = dimensions.center,
      resolution = dimensions.resolution,
      zoom = zoom_level,
      path = night_full_path,
      show_entity_info = alt_mode,
      anti_alias = anti_alias,
      hide_clouds = hide_clouds_and_fog,
      hide_fog = hide_clouds_and_fog,
      quality = jpg_quality,
      daytime = 0.5,
    })
  end
  player.print({"simple-area-screenshots.screenshot-taken", filename}, {game_state=false})
end
script.on_event(defines.events.on_player_selected_area, on_area_selected)
script.on_event(defines.events.on_player_alt_selected_area, on_area_selected)
