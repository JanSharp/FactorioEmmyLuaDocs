
local args_util = require("args_util")
local Path = require("path")

---@class Args
---@field project_name string
---@field project_id string @ same as project name but as a valid lua identifier
---@field source_extensions table<string, boolean>
---@field source_dir_path Path
---@field target_extension string
---@field target_dir_path Path
---@field auto_clean_up_target_dir boolean

---@param arg string[]
---@return Args
local function get_args(arg)
  local args = args_util.parse_args(arg)

  ---@param group_name string
  local function get_original_group_name(group_name)
    return string.gsub(group_name, "_", "-")
  end

  local function rename_groups()
    local result = {}
    ---@typelist string, string[]
    for k, v in pairs(args) do
      result[string.gsub(k, "%-", "_")] = v
    end
    args = result
  end

  ---@param group_name string
  local function assert_group(group_name)
    assert(args[group_name], "Program args missing parameter group '--"
      ..get_original_group_name(group_name).."'."
    )
  end

  ---@param group_name string
  local function convert_to_map(group_name)
    local result = {}
    for _, v in ipairs(args[group_name]) do
      result[v] = true
    end
    args[group_name] = result
  end

  ---@param group_name string
  local function single(group_name)
    assert(#args[group_name] == 1, "Program args group '--"
      ..get_original_group_name(group_name).."' must contain one single value."
    )
    args[group_name] = args[group_name][1]
  end

  ---@param group_name string
  local function flag(group_name)
    if args[group_name] then
      assert(#args[group_name] == 0, "Program args group '--"
        ..get_original_group_name(group_name)
        .."' must contain 0 subsequent values. It's a flag."
      )
      args[group_name] = true
    else
      args[group_name] = false
    end
  end

  rename_groups()

  assert_group("project_name")
  assert_group("source_extensions")
  assert_group("source_dir")
  assert_group("target_extension")
  assert_group("target_dir")

  convert_to_map("source_extensions")

  single("project_name")
  single("source_dir")
  single("target_extension")
  single("target_dir")

  ---@type string
  args.project_id = args.project_name:gsub("[^a-zA-Z0-9_]", "_")
  args.source_dir_path = Path.new(args.source_dir)
  args.source_dir = nil
  args.target_dir_path = Path.new(args.target_dir)
  args.target_dir = nil

  flag("auto_clean_up_target_dir")

  return args
end

return {
  get_args = get_args,
}
