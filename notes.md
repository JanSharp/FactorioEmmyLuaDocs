
this isn't really machine readable
```json
"name": "simple-entity-with-owner & simple-entity-with-force",
```
it would be nice if we knew what the name in ApiVariantParameterGroup
was referring to as well

```json
"return_type": "LuaEntity",
"return_description": "The created entity or `nil` if the creation failed."
```
i'd expect a return type of like
```json
{
  "type": "variant",
  "options": [
    "LuaEntity",
    "nil"
  ]
}
```

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

edit: no, not really. the way they are right now works.
  using a table like that would require some nesting which leads to recursion
  being required which increases complexity way too much
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

subclasses doesn't really help us much since we don't have access to the subclasses.
in theory one can build a list of subclasses and their attributes using the data
provided but if one was to do that the machine readable format should arguably already
have that seperation built in;
or a list of all subclasses on an ApiClass would be nice in that case,
though i don't quite have a use case for it yet because EmmyLua is not powerful enough
so i can't say if it's good or bad the way it is

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
be nice but probably not the best approach. Not sure.
edit: considering references embedded in strings are also represented as `type::member`
  it doesn't really matter because one needs the parser for it anyway, in fact it's simpler
  the way it is in that case... though the embedded references in descriptions are also a
  talking point. if it was to change, all occuranes of `type::member` would have to change.

ApiEvent has subclasses and see_also but nothing is using it

LuaLazyLoadedValue doesn't say anything about it's generic-ness and it's referred to as just LazyLoadedValue.
This is a tricky situation.
LuaCustomTable doesn't say anything about generics either.

operators should most probably be defined differently.
them being attributes with the names `operator #` and `operator []`
and methods with the name `operator ()` feels wrong

not all function types are defined as ApiComplexTypes while others are
```json
"type": "function"
```
vs
```json
"type": {
  "type": "function",
  "parameters": []
}
```
the latter being preferable

LuaControl::get_blueprint_entities return type has a space in it
-- TODO: check how many types have spaces in them
though it may just be `blueprint entity` and `blueprint tile`

The single use throw away types need to be extracted. Them being part of the description is, well, not great

create_entity has poor examples in terms of code practice, see `game.forces.player`.
