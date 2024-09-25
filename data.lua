local collision_mask_util = require("__core__/lualib/collision-mask-util")

data:extend({
  {
    type = "custom-input",
    name = "sas-get-snipping-tool",
    key_sequence = "SHIFT + ALT + S",
    order = "a",-- TODO
  },

  {
    type = "shortcut",
    name = "sas-get-snipping-tool",
    order = "a", -- TODO
    associated_control_input = "sas-get-snipping-tool",
    action = "spawn-item",
    item_to_spawn = "sas-snipping-tool",
    icon = "__simple-area-screenshots__/graphics/shortcut-icon-32.png",
    icon_size = 32,
    small_icon = "__simple-area-screenshots__/graphics/shortcut-icon-32.png",
    small_icon_size = 32,
  },

  {
    type = "selection-tool",
    name = "sas-snipping-tool",
    -- localised_name = { "item-name.snipping-tool" },
    icon = "__simple-area-screenshots__/graphics/shortcut-icon-64.png",
    subgroup = "tool",
    order = "c[automated-construction]-x",
    select = {
      border_color = {r=1, g=0, b=0, a=1},
      cursor_box_type = "entity", -- Doesn't matter, nothing will be selected
      mode = "nothing",
    },
    alt_select = {
      border_color = {r=0, g=0, b=1, a=1},
      cursor_box_type = "entity", -- Doesn't matter, nothing will be selected
      mode = "nothing",
    },
    draw_label_for_cursor_render = true,
    stack_size = 1,
    flags = { "only-in-cursor", "not-stackable", "spawnable" },
    place_result = "sas-dummy-entity",
  },
  {
    type = "simple-entity-with-force",
    name = "sas-dummy-entity",
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
    picture = {
      filename = "__core__/graphics/crosshair-x32.png",
      width = 32,
      height = 32,
    },
  },
})
