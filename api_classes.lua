---@meta

---@class ApiFormat
---@field application "factorio"
---@field api_version string
---@field api_format_version number
---@field classes ApiClass[]
---@field defines ApiDefine[]
---@field events ApiEvent[]

---@class ApiName
---@field name string
---@field description string

---@alias ApiType ApiBasicType|ApiComplexType
---@alias ApiBasicType string
---@class ApiComplexType
---@field type "array"|"dictionary"|"variant"|"CustomArray"|"CustomDictionary"|"function"|string
---@field key ApiType|nil @ used for "dictionary"|"CustomDictionary" and other
---@field value ApiType|nil @ used for "array"|"dictionary"|"CustomArray"|"CustomDictionary" and other
---@field options ApiType[]|nil @ used for "variant"
---@field parameters string[]|nil @ used for "function"

---@class ApiSubSeeAlso
---@field subclasses string[]|nil @ which subclasses this can be used on
---@field see_also string[]|nil @ references to members of other classes

---@class ApiClass : ApiName, ApiSubSeeAlso
---@field methods ApiMethod[]
---@field attributes ApiAttribute[]
---@field base_classes string[]

---@class ApiAttribute : ApiName, ApiSubSeeAlso
---@field type ApiType
---@field read boolean
---@field write boolean

---@class ApiMethod : ApiName, ApiSubSeeAlso
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
---@field values ApiName[]
---@field subkeys ApiDefine[]

---@class ApiEvent : ApiName
---@field data ApiParameter[]
