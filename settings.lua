data.extend{
  {
    type = "string-setting",
    name = "sas-filetype",
    setting_type = "runtime-per-user",
    default_value = "JPEG",
    allowed_values = {"JPEG", "PNG"},
    order = "a",
  },
  {
    type = "int-setting",
    name = "sas-jpg-quality",
    setting_type = "runtime-per-user",
    minimum_value = 0,
    maximum_value = 100,
    default_value = 90,
    order = "b",
  },
  {
    type = "bool-setting",
    name = "sas-alt-mode",
    setting_type = "runtime-per-user",
    default_value = true,
    order = "c",
  },
  {
    type = "bool-setting",
    name = "sas-hide-clouds-and-fog",
    setting_type = "runtime-per-user",
    default_value = true,
    order = "d",
  },
  {
    type = "string-setting",
    name = "sas-daytime",
    setting_type = "runtime-per-user",
    default_value = "daytime",
    allowed_values = {"daytime", "nighttime", "both", "noop"},
    order = "e",
  },
  {
    type = "bool-setting",
    name = "sas-anti-alias",
    setting_type = "runtime-per-user",
    default_value = true,
    order = "f",
  },
  {
    type = "int-setting",
    name = "sas-autozoom-target-px",
    setting_type = "runtime-per-user",
    minimum_value = 1,
    maximum_value = 16384,
    default_value = 2000,
    order = "g",
  },
  {
    type = "bool-setting",
    name = "sas-autozoom-always-start",
    setting_type = "runtime-per-user",
    default_value = false,
    order = "h",
  },
}
