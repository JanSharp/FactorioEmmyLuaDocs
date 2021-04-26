---@meta
local file = require("file")

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

---@param data ApiFormat
local function generate_defines(data)
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

---@param args Args
---@param data ApiFormat
local function generate(args, data)
  file.write_all_text(args.target_dir_path / "defines.lua", generate_defines(data))
end

return {
  generate = generate,
}
