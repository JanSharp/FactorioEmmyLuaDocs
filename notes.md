
```json
"return_type": "LuaEntity",
"return_description": "The created entity or `nil` if the creation failed."
```
i'd expect a return type of like
```json
{
  "complex_type": "variant",
  "options": [
    "LuaEntity",
    "nil"
  ]
}
```
or
```json
{
  "complex_type": "nullable",
  "value": "LuaEntity"
}
```
to make it non Lua specific
i need to do some mroe extensive research on this to see how many things
would even benefit from it and if it would be worth it.
The description containing the information is enough for the programmer,
but could a machine benefit from knowing it could be null too?

what to do about defines.prototypes
not quite sure, but i don't think it really benefits much to have the entire list
be part of the machine readable format or the html docs at all, because the entire
point is to be able to use the prototype hirachy without knowing what it actually is.

can a `complex_type` `function` have `ApiComplexType` parameters?

note about global definitions and their descriptions
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

what exactly is going on with the newlines in descriptions now

missing null entries in v8
