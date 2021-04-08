
---@type LFS
local lfs = require("lfs")
local json = require("json")

print(json.decode(json.encode("hello world")))
