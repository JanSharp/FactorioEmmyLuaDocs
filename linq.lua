
---@generic T
---@param t T[]
---@param selector fun(T: any): any
local function select(t, selector)
  local result = {}
  ---@diagnostic disable:no-implicit-any
  for i, v in ipairs(t) do
    result[i] = selector(v)
  end
  ---@diagnostic enable:no-implicit-any
  return result
end

return {
  select = select,
}
