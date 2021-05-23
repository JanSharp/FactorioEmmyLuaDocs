---@meta

---@class ApiFormat
---@field application '"factorio"'
---@field stage '"runtime"'
---@field api_version string
---@field api_format_version number
---@field classes ApiClass[]
---@field defines ApiDefine[]
---@field events ApiEvent[]
---@field concepts ApiConceptBase[]
---@field builtin_types ApiBuiltinType[]
---@field global_classes ApiGlobalVariable[]

---@class ApiBuiltinType : ApiName

---@class ApiGlobalVariable : ApiName
---@field type ApiType

---@class ApiDescription
---@field description string
---since every list is sorted alphabetically, in order to use data in the order it is\
---used for the html docs you must use this order property to sort the list
---@field order integer

---@class ApiName : ApiDescription
---@field name string

---@class ApiNotesAndExamples : ApiName
---@field notes string[]|nil
---@field examples string[]|nil

---@class ApiSubSeeAlso : ApiName
---@field subclasses string[]|nil @ which subclasses this can be used on
---@field see_also string[]|nil @ references to members of other classes

---@alias ApiType ApiBasicType|ApiComplexType
---@alias ApiBasicType string
---@class ApiComplexType : ApiTableTypeFields
---@field complex_type '"array"'|'"dictionary"'|'"variant"'|'"function"'|'"LuaCustomTable"'|'"LuaLazyLoadedValue"'
---@field key ApiType|nil @ used for "dictionary"|"LuaCustomTable"
---@field value ApiType|nil @ used for "array"|"dictionary"|"LuaCustomTable"|"LuaLazyLoadedValue"
---@field options ApiType[]|nil @ used for "variant"
---@field parameters string[]|nil @ used for "function"

---@class ApiClass : ApiSubSeeAlso, ApiNotesAndExamples
---@field methods ApiMethod[]
---@field attributes ApiAttribute[]
---@field operators ApiOperator[]
---@field base_classes string[]|nil

---_abstract_\
---Depending on the name it is either an ApiAttributeOperator or ApiMethodOperator\
---`ApiAttributeOperator`:
---- `"index"`
---- `"length"`
---`ApiMethodOperator`:
---- `"call"`
---@class ApiOperator : ApiName

---@class ApiAttribute : ApiSubSeeAlso, ApiNotesAndExamples
---@field type ApiType
---@field read boolean
---@field write boolean

---@class ApiAttributeOperator : ApiOperator, ApiAttribute

---@class ApiTableTypeFields
---@field parameters ApiParameter[]
---type specific parameters\
---variant_parameter_groups and variant_parameter_description are either both nil or both not nil
---@field variant_parameter_groups ApiVariantParameterGroup[]|nil
---variant_parameter_groups and variant_parameter_description are either both nil or both not nil
---@field variant_parameter_description string|nil

---@class ApiMethod : ApiSubSeeAlso, ApiNotesAndExamples, ApiTableTypeFields
---@field takes_table boolean
---@field table_is_optional boolean|nil @ not `nil` when `takes_table` is `true`
---return_type and return_description are either both `nil` or both not `nil`
---@field return_type ApiType|nil
---return_type and return_description are either both `nil` or both not `nil`
---@field return_description string|nil

---@class ApiMethodOperator : ApiOperator, ApiMethod

---@class ApiParameter : ApiName
---@field type ApiType
---@field optional boolean

---@class ApiVariantParameterGroup
---@field name string
---@field parameters ApiParameter[]

---@class ApiDefine : ApiName
---@field values ApiName[]|nil
---@field subkeys ApiDefine[]|nil

---@class ApiEvent : ApiName, ApiNotesAndExamples
---@field data ApiParameter[]

---@class ApiOption : ApiDescription
---@field type ApiType

---@class ApiConceptBase : ApiName
---@field category '"specification"'|'"concept"'|'"struct"'|'"flag"'|'"table"'|'"union"'|'"type"'

---@class ApiSpecification : ApiConceptBase, ApiNotesAndExamples
---@field options ApiOption[]

---@class ApiConcept : ApiConceptBase, ApiNotesAndExamples

---@class ApiStruct : ApiConceptBase
---@field attributes ApiAttribute[]

---@class ApiFlag : ApiConceptBase
---@field options ApiName[]

---@class ApiTableConcept : ApiConceptBase, ApiSubSeeAlso, ApiNotesAndExamples, ApiTableTypeFields

---@class ApiUnion : ApiConceptBase, ApiNotesAndExamples
---@field options ApiName[]

---@class ApiTypeConcept : ApiConceptBase

--[[

-- this was temporarily used becuase null fields were missing in v8 unintionally

{
  concept = {
    examples = "table",
    notes = "table"
  },
  flag = {
    options = "table"
  },
  specification = {
    examples = "table",
    options = "table"
  },
  struct = {
    attributes = "table"
  },
  table = {
    examples = "table",
    notes = "table",
    parameters = "table",
    see_also = "table",
    variant_parameter_description = "string",
    variant_parameter_groups = "table"
  },
  type = {},
  union = {
    notes = "table",
    options = "table"
  }
}

generated with this (vv) in main.lua

```lua
local categories = {}
for _, concept in ipairs(runtime_api_data.concepts) do
  local c = categories[concept.category]
  if not c then c = {} categories[concept.category] = c end
  for k, v in next, concept do
    c[k] = type(v)
  end
end
for _, category in next, categories do
  category.category = nil
  category.name = nil
  category.order = nil
  category.description = nil
end
print(serpent.block(categories, {comment = false, sort_keys = true}))
```

]]
