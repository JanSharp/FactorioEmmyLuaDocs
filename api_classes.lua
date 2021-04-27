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
---@field type "array"|"dictionary"|"variant"|string
---@field key ApiType|nil @ used for "dictionary" and other
---@field value ApiType|nil @ used for "array"|"dictionary" and other
---@field options ApiType[] @ used for "variant"

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
---@field variant_parameter_groups ApiVariantParameterGroup[] @ type specific parameters
---@field variant_parameter_description string|nil
---@field return_type ApiType|nil
---@field return_desription string|nil

---@class ApiParameter : ApiName
---@field type ApiType
---@field optional boolean

---@class ApiVariantParameterGroup
---@field name string
---@field parameters ApiParameter[]

---@class ApiDefine : ApiName
---@field values ApiName[]
---@field subkeys ApiDefine[]

---@class ApiEvent : ApiName, ApiSubSeeAlso
---@field data ApiParameter[]
