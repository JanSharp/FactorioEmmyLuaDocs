
local file = require("file")
local json = require("json")
local args_service = require("args_service")
local serpent = require("serpent")
local crc32 = require("crc32")
local generator = require("emmy_lua_generator")

local args = args_service.get_args(arg)

if not args.source_path:exists() then return end

local api_json = file.read_all_text(args.source_path):gsub("<br/>", "\\n")
local api_json_crc = args.debug_api_json_crc or crc32(api_json)
---@type ApiFormat
local api_data
---@type Path
local api_cache_path
---@type Path
local api_cache_crc_path

if args.cache_dir_path then
  api_cache_path = args.cache_dir_path / "api_cache.lua"
  api_cache_crc_path = args.cache_dir_path / "api_cache_crc"
  if api_cache_path:exists() and api_cache_crc_path:exists() then
    local cache_crc = tonumber(file.read_all_text(api_cache_crc_path))
    if cache_crc == api_json_crc then
      ---@type ApiFormat
      api_data = loadfile(api_cache_path:str(), "t")()
    end
  end
end

if not api_data then
  ---@type ApiFormat
  api_data = json.decode(api_json)
  if args.cache_dir_path then
    file.write_all_text(api_cache_path, serpent.dump(api_data))
    file.write_all_text(api_cache_crc_path, tostring(api_json_crc))
  end
end

generator.generate(args, api_data)
