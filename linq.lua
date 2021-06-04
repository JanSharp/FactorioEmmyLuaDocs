
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

---@generic T
---@param t T[]
---@param condition fun(T: any): any
local function where(t, condition)
  local result = {}
  local c = 0
  ---@diagnostic disable:no-implicit-any
  for _, v in ipairs(t) do
    if condition(v) then
      c = c + 1
      result[c] = v
    end
  end
  ---@diagnostic enable:no-implicit-any
  return result
end

---@generic V, RK, RV
---@param t V[]
---@param key_selector fun(value: V): RK
---@param value_selector? fun(value: V): RV @ defaults to just using the value
---@return table<RK, RV>
local function to_dict(t, key_selector, value_selector)
  local result = {}
  ---@diagnostic disable:no-implicit-any
  if value_selector then
    for _, v in ipairs(t) do
      result[key_selector(v)] = value_selector(v)
    end
  else
    for _, v in ipairs(t) do
      result[key_selector(v)] = v
    end
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
  where = where,
  to_dict = to_dict,
  copy = copy,
}
