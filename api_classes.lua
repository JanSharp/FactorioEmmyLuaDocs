---@meta

---@class ApiFormat
---@field application '"factorio"'
---@field stage '"runtime"'
---@field api_version string
---@field api_format_version number
---@field classes ApiClass[]
---@field defines ApiDefine[]
---@field events ApiEvent[]

---@class ApiName
---@field name string
---@field description string
---since every list is sorted alphabetically, in order to use data in the order it is\
---used for the html docs you must use this order property to sort the list
---@field order integer

---@class ApiNotesAndExamples : ApiName
---@field notes string[]|nil
---@field examples string[]|nil

---@class ApiSubSeeAlso : ApiName
---@field subclasses string[]|nil @ which subclasses this can be used on
---@field see_also string[]|nil @ references to members of other classes

---@alias ApiType ApiBasicType|ApiComplexType
---@alias ApiBasicType string
---@class ApiComplexType
---@field complex_type '"array"'|'"dictionary"'|'"variant"'|'"CustomArray"'|'"CustomDictionary"'|'"function"'|string
---@field key ApiType|nil @ used for "dictionary"|"CustomDictionary" and other
---@field value ApiType|nil @ used for "array"|"dictionary"|"CustomArray"|"CustomDictionary" and other
---@field options ApiType[]|nil @ used for "variant"
---@field parameters string[]|nil @ used for "function"

---@class ApiClass : ApiSubSeeAlso, ApiNotesAndExamples
---@field methods ApiMethod[]
---@field attributes ApiAttribute[]
---@field base_classes string[]|nil

---@class ApiAttribute : ApiSubSeeAlso, ApiNotesAndExamples
---@field type ApiType
---@field read boolean
---@field write boolean

---@class ApiMethod : ApiSubSeeAlso, ApiNotesAndExamples
---@field takes_table boolean
---@field parameters ApiParameter[]
---type specific parameters\
---variant_parameter_groups and variant_parameter_description are either both nil or both not nil
---@field variant_parameter_groups ApiVariantParameterGroup[]|nil
---variant_parameter_groups and variant_parameter_description are either both nil or both not nil
---@field variant_parameter_description string|nil
---return_type and return_description are either both nil or both not nil
---@field return_type ApiType|nil
---return_type and return_description are either both nil or both not nil
---@field return_description string|nil

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
