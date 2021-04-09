
---@type LFS
local lfs = require("lfs")
local json = require("json")
local args_service = require("args_service")

local args = args_service.get_args(arg)

print(json.decode(json.encode("hello world")))
