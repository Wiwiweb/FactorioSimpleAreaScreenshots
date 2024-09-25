local max_resolution = 16384

--- @param player_index uint
local function player_init(player_index)
  storage.players[player_index] = {
    last_dummy_entity = nil,
  }
end

-- Modified from flib
local function format_time(tick)
  local total_seconds = math.floor((tick or game.ticks_played) / 60)
  local seconds = total_seconds % 60
  local minutes = math.floor(total_seconds / 60) % 60
  local hours = math.floor(total_seconds / 3600)
  return string.format("%03d:%02d:%02d", hours, minutes, seconds)
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

--- @param player_table PlayerTable
local function destroy_last_entity(player_table)
  local last_entity = player_table.last_entity
  if last_entity then
    last_entity.destroy()
    player_table.last_entity = nil
  end
end

script.on_event(defines.events.on_built_entity, function(e)
  local player = game.get_player(e.player_index) --[[@as LuaPlayer]]
  local player_table = storage.players[e.player_index]
  local entity = e.created_entity
  local is_ghost = entity.name == "entity-ghost"

  -- destroy_last_entity(player_table)

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
  player_table.last_entity = entity

  log(entity.position)

  -- update tape
  -- if player_table.flags.drawing then
  --   tape.update_draw(player, player_table, entity.position, is_ghost)
  -- elseif player_table.flags.editing then
  --   tape.move(player, player_table, entity.position, entity.surface)
  -- else
  --   tape.start_draw(player, player_table, entity.position, entity.surface)
  -- end

  -- -- update the cursor
  player.cursor_stack.set_stack({ name = "sas-snipping-tool", count = 1 })
  -- set_cursor_label(player, player_table)
end, {
  { filter = "name", name = "sas-dummy-entity" },
  { filter = "ghost_name", name = "sas-dummy-entity" },
})

script.on_event(defines.events.on_player_selected_area, function(e)
  log("PLACED: " .. serpent.line(e.area))
  log(serpent.block(e))

  local game_id = game.default_map_gen_settings.seed % 10000 -- First 4 digits
  local path = string.format("simple-area-screenshots/%s_%s_%s.png", game_id, format_time(e.tick), e.surface.name)

  local width = e.area.right_bottom.x - e.area.left_top.x
  local height = e.area.right_bottom.y - e.area.left_top.y

  local zoom = 1
	local resX = math.floor(width * 32 * zoom)
	local resY = math.floor(height * 32 * zoom)
	local posX = e.area.left_top.x + width / 2
	local posY = e.area.left_top.y + height / 2

  if resX <= 0 or resY <= 0 then
    return -- Silently abort
  end
  if resX > max_resolution or resY > max_resolution then
    game.get_player(e.player_index).print({"simple-area-screenshots.screenshot-too-big", max_resolution})
    resX = math.min(resX, max_resolution)
    resY = math.min(resY, max_resolution)
  end

	game.take_screenshot({
		by_player = e.player_index,
		surface = e.surface,
		position = {posX, posY},
		resolution = {resX, resY},
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
