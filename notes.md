
this isn't really machine readable
"name": "simple-entity-with-owner & simple-entity-with-force",
it would be mice if we knew what the name in ApiVariantParameterGroup
was referring to as well

"return_type": "LuaEntity",
"return_description": "The created entity or `nil` if the creation failed."
machine would expect a return type of like `["LuaEntity", "nil"]`

something is off here, those spaces need to be trimmed:
```json
{
  "name": "rich_text_setting",
  "description": "How this GUI element handles rich text.",
  "subclasses": [
    "LuaLabelStyle",
    " LuaTextBoxStyle",
    " LuaTextFieldStyle"
  ],
  "see_also": null,
  "type": "defines.rich_text_setting",
  "read": true,
  "write": true
},
```

```json
"type": "defines.foo"
```
could be represented better, maybe like
```json
"type": {
  "type": "defines",
  "define": "foo"
}
```

subclasses doesn't really help us much since we don't have access to the subclasses
in theory one can build a list of subclasses and their attributes using the data
provided but if one was to do that the machine readable format should arguably already
have that seperation built in
or a list of all subclasses on ApiClass would be nice in that case
though i don't quite have a use case for it yet because EmmyLua is not powerful enough
So i can't say if it's good or bad the way it is

the see_also format is not machine readable
something like
```json
"see_also": [
  {
    "type": "LuaTechnology",
    "name": "research_unit_count"
  }
]
```
would be better. a flag saying if said member is an attribute or a method may also
be nice but probably not the best approach. Not sure

ApiEvent has subclasses and see_also but nothing is using it


