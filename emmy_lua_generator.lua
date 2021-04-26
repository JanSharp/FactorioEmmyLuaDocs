
---@type LFS
local lfs = require("lfs")
local file = require("file")
local serpent = require("serpent")

---@type Args
local args
---@type ApiFormat
local data
---@type table<string, boolean>
local valid_target_files

---@param name string
---@param text string
local function write_file_to_target(name, text)
  valid_target_files[name] = true
  file.write_all_text(args.target_dir_path / name, text)
end

local function delete_invalid_files_from_target()
  ---@type string
  for entry in lfs.dir(args.target_dir_path:str()) do
    if entry ~= "." and entry ~= ".." then
      ---@type string
      local entry_path = (args.target_dir_path / entry):str()
      if lfs.attributes(entry_path, "mode") == "file" then
        if not valid_target_files[entry] then
          os.remove(entry_path)
        end
      end
    end
  end
end

---@param description string
---@return string
local function convert_description(description)
  if description == "" then
    return ""
  else
    return "---"..description:gsub("\n", "\n---\n---").."\n"
  end
end

---convert a string to a valid lua identifier
---@param str string
---@return string
local function to_id(str)
  str = str:gsub("[^a-zA-Z0-9_]", "_")
  return str:find("^[0-9]") and "_"..str or str
end

---@param api_type ApiType
local function convert_type(api_type)
  if not api_type then
    print("Attempting to convert type where `api_type` is nil.")
    return "unknown"
  end
  if type(api_type) == "string" then
    return api_type
  else
    ---@type ApiComplexType
    local complex_type = api_type
    if complex_type.type == "array" then
      return convert_type(complex_type.value).."[]"
    elseif complex_type.type == "dictionary" then
      return "table<"..convert_type(complex_type.key)
        ..","..convert_type(complex_type.value)..">"
    elseif complex_type.type == "LazyLoadedValue" then
      -- EmmyLua/sumneko.lua do not support generic type classes
      return "LuaLazyLoadedValue<"..convert_type(complex_type.value)..",nil>"
    else
      print("Unable to convert complex type "..serpent.line(complex_type, {comment = false})..".")
      return complex_type.type
    end
  end
end

local function generate_defines()
  local result = {}
  local c = 0
  ---@param part string
  local function add(part)
    c = c + 1
    result[c] = part
  end
  add("---@meta\n---@class defines\ndefines={\n")
  ---@param define ApiDefine
  ---@param name_prefix string
  local function add_define(define, name_prefix)
    add(convert_description(define.description))
    add("---@class "..name_prefix..define.name.."\n"..to_id(define.name).."={\n")
    name_prefix = name_prefix..define.name.."."
    for _, subkey in ipairs(define.subkeys) do
      add_define(subkey, name_prefix)
    end
    for _, value in ipairs(define.values) do
      add(convert_description(value.description))
      add(to_id(value.name).."=0,\n")
    end
    add("},\n")
  end
  for _, define in ipairs(data.defines) do
    add_define(define, "defines.")
  end
  add("}")
  return table.concat(result)
end

local function generate_events()
  local result = {}
  local c = 0
  ---@param part string
  local function add(part)
    c = c + 1
    result[c] = part
  end
  add("---@meta\n")
  for _, event in ipairs(data.events) do
    add(convert_description(event.description))
    add("---@class "..event.name.."\n")
    for _, param in ipairs(event.data) do
      add(convert_description(param.description))
      add("---@field "..param.name.." "..convert_type(param.type)
        ..(param.optional and "|nil" or "").."\n")
    end
  end
  return table.concat(result)
end

---@param _args Args
---@param _data ApiFormat
local function generate(_args, _data)
  args = _args
  data = _data
  valid_target_files = {}
  write_file_to_target("defines.lua", generate_defines(data))
  write_file_to_target("events.lua", generate_events(data))
  delete_invalid_files_from_target()
  args = nil
  data = nil
  valid_target_files = nil
end

return {
  generate = generate,
}
