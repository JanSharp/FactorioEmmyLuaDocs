
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

subclasses doesn't really help us much since we don't have access to the subclasses.
in theory one can build a list of subclasses and their attributes using the data
provided but if one was to do that the machine readable format should arguably already
have that seperation built in;
or a list of all subclasses on an ApiClass would be nice in that case,
though i don't quite have a use case for it yet because EmmyLua is not powerful enough
so i can't say if it's good or bad the way it is

operators should most probably be defined differently.
them being attributes with the names `operator #` and `operator []`
and methods with the name `operator ()` feels wrong
-----
different draft:
Imo operators are their own thing, not attributes or methods, even if they are all methods in disguise in c++.
There are currently 3 different operators:
attributes with the names `operator #` and `operator []`
and methods with the name `operator ()`

LuaControl::get_blueprint_entities return type has a space in it
-- TODO: check how many types have spaces in them
though it may just be `blueprint entity` and `blueprint tile`

create_entity has poor examples in terms of code practice, see `game.forces.player`.

what to do about defines.prototypes

not sure what i think about AnyBasic being used for Tags. I mean it's not wrong, i guess.
Actually i know what i think. It's not accurate because tags specifically only allow
tables with strings as their keys, AnyBasic does not have that restriction.

some code used to test which descriptions are empty strings and which are null to reprsent "no description":
```lua
-- for _, class in ipairs(api_data.classes) do
--   if class.description == "" then
--     print("string")
--   end
--   if not class.description then
--     print("null")
--   end
-- end

-- for _, class in ipairs(api_data.classes) do
--   for _, attribute in ipairs(class.attributes) do
--     if attribute.description == "" then
--       print("string")
--     end
--     if not attribute.description then
--       print("null")
--     end
--   end
-- end

-- for _, class in ipairs(api_data.classes) do
--   for _, method in ipairs(class.methods) do
--     if method.description == "" then
--       print("string")
--     end
--     if not method.description then
--       print("null")
--     end
--   end
-- end

-- for _, define in ipairs(api_data.defines) do
--   if define.description == "" then
--     print("string")
--   end
--   if not define.description then
--     print("null")
--   end
-- end

-- for _, define in ipairs(api_data.defines) do
--   for _, value in ipairs(define.values) do
--     if value.description == "" then
--       print("string")
--     end
--     if not value.description then
--       print("null")
--     end
--   end
-- end

-- for _, event in ipairs(api_data.events) do
--   if event.description == "" then
--     print("string")
--   end
--   if not event.description then
--     print("null")
--   end
-- end

-- for _, event in ipairs(api_data.events) do
--   for _, parameter in ipairs(event.data) do
--     if parameter.description == "" then
--       print("string")
--     end
--     if not parameter.description then
--       print("null")
--     end
--   end
-- end

-- for _, class in ipairs(api_data.classes) do
--   for _, method in ipairs(class.methods) do
--     for _, group in ipairs(method.variant_parameter_groups) do
--       for _, parameter in ipairs(group.parameters) do
--         if parameter.description == "" then
--           print("string")
--         end
--         if not parameter.description then
--           print("null")
--         end
--       end
--     end
--   end
-- end

-- for _, class in ipairs(api_data.classes) do
--   for _, method in ipairs(class.methods) do
--     for _, parameter in ipairs(method.parameters) do
--       if parameter.description == "" then
--         print("string")
--       end
--       if not parameter.description then
--         print("null")
--       end
--     end
--   end
-- end

-- for _, class in ipairs(api_data.classes) do
--   for _, method in ipairs(class.methods) do
--     if method.variant_parameter_description == "" then
--       print("string")
--     end
--     if not method.variant_parameter_description then
--       print("null")
--     end
--   end
-- end

-- for _, class in ipairs(api_data.classes) do
--   for _, method in ipairs(class.methods) do
--     if method.return_description == "" then
--       print("string")
--     end
--     if not method.return_description then
--       print("null")
--     end
--   end
-- end
```
