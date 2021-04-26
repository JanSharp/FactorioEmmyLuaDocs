
---@type LFS
local lfs = require("lfs")

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

return {
  read_all_text = read_all_text,
  write_all_text = write_all_text,
}
