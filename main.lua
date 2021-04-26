
---@type LFS
local lfs = require("lfs")
local json = require("json")
local args_service = require("args_service")
local serpent = require("serpent")

---read an entire file
---@param path Path
---@return string
local function read_all_text(path)
  local file = io.open(path:str(), "r")
  local result = file:read("a")
  file:close()
  return result
end

---read an entire file
---@param path Path
---@param text string
local function write_all_text(path, text)
  if path:exists() then
    local prev_text = read_all_text(path)
    if prev_text == text then
      return
    end
  else
    local dir_path = path:sub(1, path:length() - 1)
    if not dir_path:exists() then
      lfs.mkdir(dir_path:str())
    end
  end
  local file = io.open(path:str(), "w")
  file:write(text)
  file:close()
end

---iterate a table in a sorted order
---@param t table
---@param comp? fun(left: any, right: any): boolean @ is left smaller than right? defaults to comparing the keys using the default lua < operator
---@return fun(): any, any @ iterator
local function sorted_pairs(t, comp)
  local list = {}
  ---@diagnostic disable: no-implicit-any
  for k, v in pairs(t) do
    list[#list+1] = {k = k, v = v}
  end
  ---@diagnostic enable: no-implicit-any
  comp = comp or function(left, right)
    return left.k < right.k
  end
  table.sort(list, comp)
  local i = 1
  return function()
    local elem = list[i]
    if not elem then return end
    i = i + 1
    return elem.k, elem.v
  end
end

local args = args_service.get_args(arg)

---@type table
local source

---@type Path
local api_cache_path = args.cache_dir_path / "api_cache.dat"
if api_cache_path:exists() then
  -- TODO: add cache validity/up to date check
  ---@type table
  source = loadfile(api_cache_path:str(), "t")()
else
  if not args.source_path:exists() then return end
  ---@type table
  source = json.decode(read_all_text(args.source_path):gsub("<br/>", "\\n"))
  write_all_text(api_cache_path, serpent.dump(source))
end

local breakpoint
