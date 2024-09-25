--- @class PlayerTable
--- @field start_of_selection MapPosition?
--- @field increased_build_distance boolean

local max_resolution = 16384

--- @param player_index uint
local function player_init(player_index)
  storage.players[player_index] = {
    start_of_selection = nil,
    increased_build_distance = false,
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

script.on_init(function()
  log("on_init")
  --- @type table<uint, PlayerTable>
  storage.players = {}

  for _, player in pairs(game.players) do
    player_init(player.index)
  end
end)

script.on_event(defines.events.on_player_created, function(e)
  player_init(e.player_index)
end)

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

script.on_event(defines.events.on_player_cursor_stack_changed, function(e)
  local player = game.get_player(e.player_index) --[[@as LuaPlayer]]
  local player_table = storage.players[e.player_index]
  if not player_table then
    return
  end
  local cursor_stack = player.cursor_stack
  if cursor_stack and cursor_stack.valid_for_read and cursor_stack.name == "sas-snipping-tool" then
    if not player_table.increased_build_distance then
      player.character_build_distance_bonus = player.character_build_distance_bonus + 1000000
      player_table.increased_build_distance = true
      log("INCREASED DISTANCE")
    end
  elseif player_table.increased_build_distance then
    local build_distance_bonus = player.character_build_distance_bonus
    if build_distance_bonus >= 1000000 then -- Safety check against mods who might have reduced it in the meantime.
      player.character_build_distance_bonus = build_distance_bonus - 1000000
    end
    player_table.increased_build_distance = false
    log("DECREASED DISTANCE")
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
  else
    local zoom = 1
    local dimensions = get_dimensions_from_box(player_table.start_of_selection, entity.position, zoom)
    cursor_stack.label = string.format("%sx%spx", dimensions.resolution.x, dimensions.resolution.y)
  end

  -- entity.destroy()
end, {
  { filter = "name", name = "sas-dummy-entity" },
  { filter = "ghost_name", name = "sas-dummy-entity" },
})

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

  local game_id = game.default_map_gen_settings.seed % 10000 -- First 4 digits
  local path = string.format("simple-area-screenshots/%s_%s_%s.png", game_id, format_time(e.tick), e.surface.name)

  local zoom = 1
  local dimensions = get_dimensions_from_box(e.area.left_top, e.area.right_bottom, zoom)

  if dimensions.resolution.x <= 0 or dimensions.resolution.y <= 0 then
    return -- Silently abort
  end
  if dimensions.resolution.x > max_resolution or dimensions.resolution.y > max_resolution then
    game.get_player(e.player_index).print({"simple-area-screenshots.screenshot-too-big", max_resolution})
    resX = math.min(resX, max_resolution)
    resY = math.min(resY, max_resolution)
  end

	game.take_screenshot({
		by_player = e.player_index,
		surface = e.surface,
		position = dimensions.center,
		resolution = dimensions.resolution,
		zoom = zoom,
    path = path,
		daytime = 0
	})
  game.get_player(e.player_index).print({"simple-area-screenshots.screenshot-taken", path})
end)


-- if global.snip[index].output_format_index == 1 then
--   local bytesPerPixel = 2
--   size = bytesPerPixel * width * height

--   if size > 999999999 then
--       size = (math.floor(size / 100000000) / 10) .. " GiB"
--   elseif size > 999999 then
--       size = (math.floor(size / 100000) / 10) .. " MiB"
--   elseif size > 999 then
--       size = (math.floor(size / 100) / 10) .. " KiB"
--   else
--       size = size .. " B"
--   end
-- end
