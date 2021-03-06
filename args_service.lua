
local args_util = require("args_util")
local Path = require("path")

---@class Args
---@field source_path Path
---@field cache_dir_path Path|nil
---@field target_dir_path Path
---@field debug_runtime_api_json_crc number|nil
---@field disable_specific_diagnostics string[]
---@field factorio_version string @ format: `major.minor.patch`

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

  -- ---@param group_name string
  -- local function convert_to_map(group_name)
  --   local result = {}
  --   for _, v in ipairs(args[group_name]) do
  --     result[v] = true
  --   end
  --   args[group_name] = result
  -- end

  ---@param group_name string
  local function single(group_name)
    if not args[group_name] then return end
    assert(#args[group_name] == 1, "Program args group '--"
      ..get_original_group_name(group_name).."' must contain one single value."
    )
    ---@type string
    args[group_name] = args[group_name][1]
  end

  -- ---@param group_name string
  -- local function flag(group_name)
  --   if args[group_name] then
  --     assert(#args[group_name] == 0, "Program args group '--"
  --       ..get_original_group_name(group_name)
  --       .."' must contain 0 subsequent values. It's a flag."
  --     )
  --     args[group_name] = true
  --   else
  --     args[group_name] = false
  --   end
  -- end

  rename_groups()

  assert_group("source_file")
  assert_group("target_dir")

  single("source_file")
  single("cache_dir")
  single("target_dir")
  single("debug_runtime_api_json_crc")
  single("factorio_version")

  args.source_path = Path.new(args.source_file)
  args.source_file = nil
  if args.cache_dir then
    args.cache_dir_path = Path.new(args.cache_dir)
    args.cache_dir = nil
  end
  args.target_dir_path = Path.new(args.target_dir)
  args.target_dir = nil
  args.debug_runtime_api_json_crc = args.debug_runtime_api_json_crc and tonumber(args.debug_runtime_api_json_crc)

  return args
end

return {
  get_args = get_args,
}
