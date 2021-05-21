
local json = require("json")
local file = require("file")
local serpent = require("serpent")
local args_util = require("args_util")
local Path = require("path")

---@class ToLuaBlockArgs
---@field file_path Path

---@param arg string[]
---@return ToLuaBlockArgs
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
  local function single(group_name)
    if not args[group_name] then return end
    assert(#args[group_name] == 1, "Program args group '--"
      ..get_original_group_name(group_name).."' must contain one single value."
    )
    ---@type string
    args[group_name] = args[group_name][1]
  end

  rename_groups()

  assert_group("file")

  single("file")

  args.file_path = Path.new(args.file)
  args.file = nil

  return args
end

local args = get_args(arg)
local file_path = args.file_path

if file_path:exists() then
  local data = json.decode(file.read_all_text(file_path)) ---@type ApiFormat
  local function remove_stuff(t)
    t.order = nil
    t.description = nil
    t.return_description = nil
    t.examples = nil
    t.notes = nil
    -- t.table_is_optional = nil
    local remove_operators = false
    for k, v in pairs(t) do ---@type table|any
      if type(v) == "table" then
        -- if k == "operators" and not next(v) then
        --   remove_operators = true
        -- end
        remove_stuff(v)
      end
    end
    -- if remove_operators then
    --   t.operators = nil
    -- end
  end
  remove_stuff(data)
  local target_path = file_path:sub(1, -2) / (file_path:filename()..".lua")
  file.write_all_text(target_path, serpent.block(data, {
    comment = false,
    name = "data",
  }))
end

--[[

this file is meant to be run separately and is purely for diffing purposes of the different json versions
i put it into the repo by accident but tbh it's not bad if it's in there
usage is like this for example:

./lua to_lua_block.lua -- --file ../.ClonedRepositories/SpecialStuff/output/api_v8.json

]]

-- fix semantics