-- Based on trial and error rather than any sound theory
-- filesize = a * pxl_count + c
-- a and c depend on jpg quality (or png)
-- c doesn't matter too much and overinflates small screenshots so I just ignore it

local jpg_parameter_table = {
  [10]= 0.0635,
  [20]= 0.105,
  [30]= 0.141,
  [40]= 0.170,
  [50]= 0.198,
  [60]= 0.229,
  [70]= 0.279,
  [80]= 0.367,
  [82]= 0.393,
  [84]= 0.425,
  [86]= 0.463,
  [88]= 0.511,
  [90]= 0.568,
  [91]= 0.601,
  [92]= 0.637,
  [93]= 0.688,
  [94]= 0.752,
  [95]= 0.826,
  [96]= 0.939,
  [97]= 1.07,
  [98]= 1.25,
  [99]= 1.60,
  [100]= 1.90,
}

local png_parameter = 2.02

--- @param starting_quality uint
--- @param direction int
--- @return uint
local function find_closest_known_quality(starting_quality, direction)
  local try_quality = starting_quality + direction
  while 0 < try_quality and try_quality < 100 do
    if jpg_parameter_table[try_quality] ~= nil then
      return try_quality
    end
    try_quality = try_quality + direction
  end
  error("Error in jpg parameter table")
end

--- @param player_index uint
--- @return float
function get_filesize_parameter(player_index)
  local player = game.get_player(player_index) --[[@as LuaPlayer]]
  if player.mod_settings["sas-filetype"].value == "PNG" then
    return png_parameter
  end

  local jpg_quality = player.mod_settings["sas-jpg-quality"].value --[[@as uint]]
  if jpg_parameter_table[jpg_quality] ~= nil then
    -- log(string.format("Found: %d = %d", jpg_quality,  jpg_parameter_table[jpg_quality]))
    return jpg_parameter_table[jpg_quality]
  elseif jpg_quality <= 10 then
    return jpg_parameter_table[10]
  else
    -- linear interpolate between surrounding values (good enough)
    local lower_known_quality = find_closest_known_quality(jpg_quality, -1)
    local upper_known_quality = find_closest_known_quality(jpg_quality, 1)
    local lerp_weight = (jpg_quality - lower_known_quality) / (upper_known_quality - lower_known_quality)
    local lower_known_parameter = jpg_parameter_table[lower_known_quality]
    local upper_known_parameter = jpg_parameter_table[upper_known_quality]
    local parameter = (upper_known_parameter - lower_known_parameter) * lerp_weight + lower_known_parameter
    -- log(string.format("Lerped: %d = %f (%d%% between %d=%f and %d=%f)",
    --   jpg_quality, parameter, lerp_weight*100, lower_known_quality, lower_known_parameter, upper_known_quality, upper_known_parameter))
    return parameter
  end
end

function get_filesize_string(player_table, pixel_count)
  local digits = player_table.filesize_parameter * pixel_count
  local unit = "B"
  if digits >= 1024 then
    digits = digits / 1024
    unit = "KB"
  end
  if digits >= 1024 then
    digits = digits / 1024
    unit = "MB"
  end
  if digits >= 1024 then
    digits = digits / 1024
    unit = "GB" -- Probably not, haha
  end

  -- This is an approximation, only show 2 significant digits.
  if digits >= 1000 then
    digits = math.floor(digits / 100 + 0.5) * 100 -- Round to nearest 100
  elseif digits >= 100 then
    digits = math.floor((digits / 10 + 0.5) ) * 10 -- Round to nearest 10
  end
  if digits >= 10 then
    return string.format("%d%s", digits, unit)
  else
    return string.format("%.2g%s", digits, unit)
  end
end
