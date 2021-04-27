
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

---@generic TKey, TValue
---@param t table<TKey, TValue>
---@return table<TKey, TValue>
local function copy(t)
  local result = {}
  ---@diagnostic disable:no-implicit-any
  for k, v in pairs(t) do
    result[k] = v
  end
  ---@diagnostic enable:no-implicit-any
  return result
end

return {
  select = select,
  copy = copy,
}
