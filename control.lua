filesize = require("scripts/filesize")

--- @class PlayerTable
--- @field start_of_selection MapPosition?
--- @field end_of_selection MapPosition?
--- @field tool_in_progress boolean
--- @field map_view_during_tool_use boolean
--- @field filesize_parameter float
--- @field zoom_index uint

local max_resolution = 16384
local zoom_levels = {0.125, 0.25, 0.5, 1, 2, 4, 8, 16, 32}

--- @param player_index uint
local function player_init(player_index)
  storage.players[player_index] = {
    start_of_selection = nil,
    end_of_selection = nil,
    tool_in_progress = false,
    map_view_during_tool_use = false,
    filesize_parameter = get_filesize_parameter(player_index),
    zoom_index = 4,
  }
end

-- Modified from flib
local function format_time(tick)
  local total_seconds = math.floor((tick or game.ticks_played) / 60)
  local seconds = total_seconds % 60
  local minutes = math.floor(total_seconds / 60) % 60
  local hours = math.floor(total_seconds / 3600)
  return string.format("%04d:%02d:%02d", hours, minutes, seconds)
end


--- @param pos1 MapPosition
--- @param pos2 MapPosition
--- @param zoom uint
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

local function update_cursor_label(player_table, cursor_stack)
  local zoom = zoom_levels[player_table.zoom_index]
  if player_table.map_view_during_tool_use or
     player_table.start_of_selection == nil or
     player_table.start_of_selection == player_table.end_of_selection then
    cursor_stack.label = string.format("Zoom: x%s", zoom)
  else
    local dimensions = get_dimensions_from_box(player_table.start_of_selection, player_table.end_of_selection, zoom)
    local pixel_count = dimensions.resolution.x * dimensions.resolution.y
    cursor_stack.label = string.format("Zoom: x%s | %sx%spx (%s)",
      zoom, dimensions.resolution.x, dimensions.resolution.y, get_filesize_string(player_table, pixel_count))
  end
end

local function update_zoom(player_index, direction)
  local player_table = storage.players[player_index]
  if not player_table then return end
  if not player_table.tool_in_progress then return end -- Only allow this shortcut when holding the tool

  local new_zoom_index = player_table.zoom_index + direction
  if new_zoom_index <= 0 or #zoom_levels < new_zoom_index then return end

  player_table.zoom_index = new_zoom_index
  local player = game.get_player(player_index) --[[@as LuaPlayer]]
  local cursor_stack = player.cursor_stack
  if cursor_stack == nil then
    return
  end
  update_cursor_label(player_table, cursor_stack)
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
  log("on_player_cursor_stack_changed")
  local player = game.get_player(e.player_index) --[[@as LuaPlayer]]
  local player_table = storage.players[e.player_index]
  if not player_table then
    return
  end
  local cursor_stack = player.cursor_stack
  local holding_tool = cursor_stack and cursor_stack.valid_for_read and cursor_stack.name == "sas-snipping-tool"
  if player_table.tool_in_progress then
    if not holding_tool then
      -- Tool use ended
      log("TOOL USE ENDED")
      player_table.tool_in_progress = false
      player_table.map_view_during_tool_use = false
      player_table.start_of_selection = nil
      player_table.end_of_selection = nil
      local build_distance_bonus = player.character_build_distance_bonus
      if build_distance_bonus >= 1000000 then -- Safety check against mods who might have reduced it in the meantime.
        player.character_build_distance_bonus = build_distance_bonus - 1000000
      end
    end
  else
    if holding_tool then
      -- Tool use started
      log("TOOL USE STARTED")
      player_table.tool_in_progress = true
      player_table.map_view_during_tool_use = player.render_mode == defines.render_mode.chart
      player.character_build_distance_bonus = player.character_build_distance_bonus + 1000000
      update_cursor_label(player_table, cursor_stack)
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
        log("MAP VIEW WAS USED")
          player_table.map_view_during_tool_use = true
          player.cursor_stack.label = ""
      end
    end
  end
end)

script.on_event(defines.events.on_built_entity, function(e)
  local player = game.get_player(e.player_index) --[[@as LuaPlayer]]
  local player_table = storage.players[e.player_index]
  local entity = e.created_entity
  local is_ghost = entity.name == "entity-ghost"

  if is_ghost then
    -- instantly revive the entity if it is a ghost
    local _, new_entity = entity.silent_revive()
    if not new_entity then
      return
    end
    entity = new_entity
  end
  -- make the entity invincible to prevent attacks
  entity.destructible = false

  log(entity.position)
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
  update_cursor_label(player_table, cursor_stack)

  -- entity.destroy()
end, {
  { filter = "name", name = "sas-dummy-entity" },
  { filter = "ghost_name", name = "sas-dummy-entity" }, -- TODO remove?
})

script.on_event("sas-increase-zoom", function(e)
  update_zoom(e.player_index, 1)
end)
script.on_event("sas-decrease-zoom", function(e)
  update_zoom(e.player_index, -1)
end)

script.on_event(defines.events.on_player_selected_area, function(e)
  log("PLACED: " .. serpent.line(e.area))
  local player = game.get_player(e.player_index) --[[@as LuaPlayer]]
  local player_table = storage.players[e.player_index]
  local cursor_stack = player.cursor_stack
  if cursor_stack == nil or not cursor_stack.valid_for_read or cursor_stack.name ~= "sas-snipping-tool" then
    return
  end
  cursor_stack.clear()
  player_table.start_of_selection = nil
  player_table.end_of_selection = nil

  local zoom = zoom_levels[player_table.zoom_index]
  local dimensions = get_dimensions_from_box(e.area.left_top, e.area.right_bottom, zoom)

  if dimensions.resolution.x <= 0 or dimensions.resolution.y <= 0 then
    return -- Silently abort
  end

  local player_settings = settings.get_player_settings(player)
  local anti_alias = player_settings["sas-anti-alias"].value --[[@as boolean]]

  local current_max_resolution = max_resolution
  if anti_alias then current_max_resolution = current_max_resolution / 2 end
  if dimensions.resolution.x > current_max_resolution or dimensions.resolution.y > current_max_resolution then
    local too_big_message = {"simple-area-screenshots.screenshot-too-big", current_max_resolution}
    if anti_alias then
      too_big_message = {"", too_big_message, " ", {"simple-area-screenshots.screenshot-too-big-anti-alias"}}
    end
    player.print(too_big_message)
    dimensions.resolution.x = math.min(dimensions.resolution.x, current_max_resolution)
    dimensions.resolution.y = math.min(dimensions.resolution.y, current_max_resolution)
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
		zoom = zoom,
    path = full_path,
    anti_alias = anti_alias,
    quality = jpg_quality,
		daytime = daytime,
	})

  if also_nighttime then
    local night_filename = string.format("%s_%s_%s_night.%s", game_id, format_time(e.tick), e.surface.name, file_extension)
    local night_full_path = "simple-area-screenshots/" .. filename
    game.take_screenshot({
      by_player = e.player_index,
      surface = e.surface,
      position = dimensions.center,
      resolution = dimensions.resolution,
      zoom = zoom,
      path = night_full_path,
      anti_alias = anti_alias,
      quality = jpg_quality,
      daytime = 0.5,
    })
  end
  player.print({"simple-area-screenshots.screenshot-taken", filename})
end)
