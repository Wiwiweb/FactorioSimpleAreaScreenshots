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
    default_value = 80,
    order = "b",
  },
  {
    type = "bool-setting",
    name = "sas-anti-alias",
    setting_type = "runtime-per-user",
    default_value = true,
    order = "c",
  },
  {
    type = "string-setting",
    name = "sas-daytime",
    setting_type = "runtime-per-user",
    default_value = "daytime",
    allowed_values = {"daytime", "nighttime", "noop"},
    order = "d",
  },
}
