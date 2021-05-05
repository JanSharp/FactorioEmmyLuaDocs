
---map from type name to global name
---@type table<string, string>
local result = {
  LuaGameScript = "game",
  LuaBootstrap = "script",
  LuaRemote = "remote",
  LuaCommandProcessor = "commands",
  LuaSettings = "settings",
  LuaRCON = "rcon",
  LuaRendering = "rendering",
  defines = "defines",
}

--[[

doing it like this, where the class definition and global definition
is in the same palce also adds the description to the global
for some reason, potentially because of lua library globals and sumneko.lua internals,
doing
```
foo = {} ---@type foo
```
does not add the description for the class `foo` to the global `foo`
while
```
local foo ---@type foo
```
does add it to the local `foo`

that should explain why this additional complexity has been added

]]

return result
