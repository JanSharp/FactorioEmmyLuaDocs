
---@alias GroupedArgs table<string, string[]>

---comment
---@param args string[]
---@return GroupedArgs
local function parse_args(args)
  local current_group = {}
  ---@type GroupedArgs
  local result = {
    unmapped = current_group,
  }
  for _, arg in ipairs(args) do
    if string.sub(arg, 1, 2) == "--" then
      current_group = {}
      result[string.sub(arg, 3)] = current_group
    else
      current_group[#current_group+1] = arg
    end
  end
  if #result.unmapped == 0 then
    result.unmapped = nil
  end
  return result
end

return {
  parse_args = parse_args,
}
