
local file = require("file")
local json = require("json")
local args_service = require("args_service")
local serpent = require("serpent")
local crc32 = require("crc32")
local generator = require("emmy_lua_generator")

local args = args_service.get_args(arg)

if not args.source_path:exists() then return end

local runtime_api_json --- @type string
local function get_runtime_api_json()
  if not runtime_api_json then
    runtime_api_json = file.read_all_text(args.source_path)
  end
  return runtime_api_json
end
local runtime_api_json_crc ---@type integer
local runtime_api_data ---@type ApiFormat
local runtime_api_cache_path ---@type Path
local runtime_api_cache_crc_path ---@type Path

if args.cache_dir_path then
  runtime_api_json_crc = args.debug_runtime_api_json_crc or crc32(get_runtime_api_json())
  runtime_api_cache_path = args.cache_dir_path / "runtime-api-cache.lua"
  runtime_api_cache_crc_path = args.cache_dir_path / "runtime-api-cache-crc"
  if runtime_api_cache_path:exists() and runtime_api_cache_crc_path:exists() then
    local cache_crc = tonumber(file.read_all_text(runtime_api_cache_crc_path))
    if cache_crc == runtime_api_json_crc then
      runtime_api_data = loadfile(runtime_api_cache_path:str(), "t")() ---@type ApiFormat
    end
  end
end

if not runtime_api_data then
  runtime_api_data = json.decode(get_runtime_api_json()) ---@type ApiFormat
  if args.cache_dir_path then
    if args.debug_runtime_api_json_crc then
      runtime_api_json_crc = crc32(get_runtime_api_json())
    end
    file.write_all_text(runtime_api_cache_path, serpent.dump(runtime_api_data))
    file.write_all_text(runtime_api_cache_crc_path, tostring(runtime_api_json_crc))
  end
end

generator.generate(args, runtime_api_data)
