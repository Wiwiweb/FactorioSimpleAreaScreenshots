local invisible_selection = {
  border_color = {a=0}, -- Invisible
  cursor_box_type = "entity", -- Doesn't matter, nothing will be selected
  mode = "nothing",
}

data:extend({
  {
    type = "custom-input",
    name = "sas-get-snipping-tool",
    key_sequence = "SHIFT + ALT + S",
    order = "a",
  },
  {
    type = "custom-input",
    name = "sas-increase-zoom",
    key_sequence = "SHIFT + mouse-wheel-up",
    consuming = "game-only",
    order = "b",
  },
  {
    type = "custom-input",
    name = "sas-decrease-zoom",
    key_sequence = "SHIFT + mouse-wheel-down",
    consuming = "game-only",
    order = "c",
  },

  {
    type = "shortcut",
    name = "sas-get-snipping-tool",
    order = "a",
    associated_control_input = "sas-get-snipping-tool",
    action = "spawn-item",
    item_to_spawn = "sas-snipping-tool",
    icon = "__simple-area-screenshots__/graphics/camera-32.png",
    icon_size = 32,
    small_icon = "__simple-area-screenshots__/graphics/camera-24.png",
    small_icon_size = 24,
  },

  {
    type = "selection-tool",
    name = "sas-snipping-tool",
    localised_name = {"item-name.sas-snipping-tool"},
    icon = "__simple-area-screenshots__/graphics/camera-cursor-32.png",
    icon_size = 32,
    subgroup = "tool",
    order = "c[automated-construction]-z",
    select = {
      border_color = {r=1, g=0, b=0, a=1},
      cursor_box_type = "entity", -- Doesn't matter, nothing will be selected
      mode = "nothing",
    },
    alt_select = invisible_selection,
    super_forced_select = invisible_selection,
    reverse_select = invisible_selection,
    draw_label_for_cursor_render = true,
    stack_size = 1,
    flags = { "only-in-cursor", "not-stackable", "spawnable" },
    hidden = true,
    place_result = "sas-dummy-entity",
    mouse_cursor = "sas-tool-cursor",
  },
  {
    type = "mouse-cursor",
    name = "sas-tool-cursor",
    filename = "__simple-area-screenshots__/graphics/camera-cursor-32.png",
    hot_pixel_x = 1,
    hot_pixel_y = 1,
  },
  {
    type = "simple-entity-with-force",
    name = "sas-dummy-entity",
    localised_name = "Simple Area Screenshots dummy entity",
    flags = { "not-on-map", "placeable-off-grid", "not-deconstructable", "not-blueprintable" },
    hidden = true,
    selectable_in_game = false,
    allow_copy_paste = false,
    alert_when_damaged = false,
    build_sound = {
      filename = "__core__/sound/silence-1sec.ogg",
    },
    collision_mask = {
      layers = {},
    },
    subgroup = "other",
    order = "zzzzz",
    -- picture = {
    --   filename = "__core__/graphics/crosshair-x32.png",
    --   width = 32,
    --   height = 32,
    -- },
  },
  {
    type = "sprite",
    name = "sas_icon_white",
    filename = "__simple-area-screenshots__/graphics/camera-white-32.png",
    size = 32,
    flags = { "icon" },
  },
})
