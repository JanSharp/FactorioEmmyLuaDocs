
local file = require("file")
local json = require("json")
local args_service = require("args_service")
local serpent = require("serpent")
local crc32 = require("crc32")
local generator = require("emmy_lua_generator")

local args = args_service.get_args(arg)

if not args.source_path:exists() then return end

local api_json --- @type string
local function get_api_json()
  if not api_json then
    api_json = file.read_all_text(args.source_path)
  end
  return api_json
end
local api_json_crc ---@type integer
local api_data ---@type ApiFormat
local api_cache_path ---@type Path
local api_cache_crc_path ---@type Path

if args.cache_dir_path then
  api_json_crc = args.debug_api_json_crc or crc32(get_api_json())
  api_cache_path = args.cache_dir_path / "api_cache.lua"
  api_cache_crc_path = args.cache_dir_path / "api_cache_crc"
  if api_cache_path:exists() and api_cache_crc_path:exists() then
    local cache_crc = tonumber(file.read_all_text(api_cache_crc_path))
    if cache_crc == api_json_crc then
      api_data = loadfile(api_cache_path:str(), "t")() ---@type ApiFormat
    end
  end
end

if not api_data then
  api_data = json.decode(get_api_json()) ---@type ApiFormat
  if args.cache_dir_path then
    if args.debug_api_json_crc then
      api_json_crc = crc32(get_api_json())
    end
    file.write_all_text(api_cache_path, serpent.dump(api_data))
    file.write_all_text(api_cache_crc_path, tostring(api_json_crc))
  end
end

generator.generate(args, api_data)
