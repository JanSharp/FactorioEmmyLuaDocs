
---@type LFS
local lfs = require("lfs")
local json = require("json")
local args_service = require("args_service")
local serpent = require("serpent")
local crc32 = require("crc32")
local generator = require("emmy_lua_generator")

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

local args = args_service.get_args(arg)

if not args.source_path:exists() then return end

local api_json = read_all_text(args.source_path):gsub("<br/>", "\\n")
local api_json_crc = args.debug_api_json_crc or crc32(api_json)
---@type ApiFormat
local api_data

---@type Path
local api_cache_path = args.cache_dir_path / "api_cache.lua"
---@type Path
local api_cache_crc_path = args.cache_dir_path / "api_cache_crc"

if api_cache_path:exists() and api_cache_crc_path:exists() then
  local cache_crc = tonumber(read_all_text(api_cache_crc_path))
  if cache_crc == api_json_crc then
    ---@type ApiFormat
    api_data = loadfile(api_cache_path:str(), "t")()
  end
end

if not api_data then
  ---@type ApiFormat
  api_data = json.decode(api_json)
  write_all_text(api_cache_path, serpent.dump(api_data))
  write_all_text(api_cache_crc_path, tostring(api_json_crc))
end


