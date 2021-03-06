
local lfs = require("lfs") ---@type LFS
local file = require("file")
local Path = require("path")
local serpent = require("serpent")
local linq = require("linq")

local lua_keywords = require("lua_keywords")

-- naming conventions in this file and some general info

-- adding means adding to the output, which will be a file

-- converted means final format that will be written to the output file
-- this is mostly/only relevant for descriptions which will have `---` at the start
-- of each line, 2 leading spaces for line breaks that shouldn't create new paragraphs
-- and at least double \n\n for new paragraphs
-- internal references are resolved html doc links

-- formatted is an intermediate state only really used for descriptions
-- which means this is basically raw markdown
-- "resolve" is also used for this for internal references and links
-- linebreaks that shouldn't cause new paragraphs are single \n
-- new paragraphs are 2 or more
-- internal references look like `[display name](internal_reference_name)` like `[game](LuaGameScript)`
-- see `resolve_internal_reference` for more detail

-- extend_string is almost like a core building block for building descriptions

-- no description is always "" unless it is completely unused description, then it's nil
-- like return_description is only not nil if there is a return type
-- this convention of "" meaing "no description" applies everywhere in here


-- all of these get set/populated in or through the generate function
local args ---@type Args
local data ---@type ApiFormat
---indexed by formatted types
local globals_map ---@type table<string, ApiGlobalVariable>
local class_name_lut ---@type table<string, boolean>
local event_name_lut ---@type table<string, boolean>
local define_name_lut ---@type table<string, boolean>
local builtin_type_name_lut ---@type table<string, boolean>
local concept_name_lut ---@type table<string, boolean>
local table_or_array_type_name_lut ---@type table<string, ApiType>
local valid_target_files ---@type table<string, boolean>
local runtime_api_base_url ---@type string

local file_prefix

local function set_file_prefix()
  file_prefix = --"--##\n" -- ignored by sumneko.lua plugin https://github.com/JanSharp/FactorioSumnekoLuaPlugin#help-it-broke
    --.. -- for now don't ignore them because the preprocessor plugin adds the `new` keyword which needs "access" to the class definitions
    "---@meta\n" -- "ignored" by sumneko.lua https://github.com/sumneko/lua-language-server/wiki/EmmyLua-Annotations#meta
  if args.disable_specific_diagnostics then
    file_prefix = file_prefix
      ..table.concat(
        linq.select(
          args.disable_specific_diagnostics,
          function(v)
            return "---@diagnostic disable:"..v.."\n"
          end
        )
      )
  else
    file_prefix = file_prefix.."---@diagnostic disable\n"
  end
  file_prefix = file_prefix.."\n"
end

---@param name string
---@param text string
local function write_file_to_target(name, text)
  valid_target_files[name] = true
  file.write_all_text(args.target_dir_path / name, text)
end

local function delete_invalid_files_from_target()
  ---@type string
  for entry in lfs.dir(args.target_dir_path:str()) do
    if entry ~= "." and entry ~= ".." then
      ---@type string
      local entry_path = (args.target_dir_path / entry):str()
      if lfs.attributes(entry_path, "mode") == "file" then
        if not valid_target_files[entry] then
          os.remove(entry_path)
        end
      end
    end
  end
end

---@generic T
---@param t T[]
---@return T[]
local function sort_by_order(t)
  local sorted = linq.copy(t)
  table.sort(sorted, function(l, r)
    return l.order < r.order
  end)
  return sorted
end

---@param str string
---@return string|nil @ nil if str == ""
local function empty_to_nil(str)
  return str ~= "" and str or nil
end

---is this a single line string?
---@param str string
---@return boolean
local function is_single_line(str)
  return not str:find("\n")
end

---@class ExtendStringParam
---@field pre string|nil @ if str is not empty this will be preprended
---@field str string @ the part to concat which may be empty ("")
---@field post string|nil @ if str is not empty this will be appended
---if str is empty this will be used\
---pre and post will not be applied however
---@field fallback string|nil

---@param param ExtendStringParam
local function extend_string(param)
  if param.str == "" then
    return param.fallback or ""
  else
    return (param.pre and param.pre or "")
      ..param.str
      ..(param.post and param.post or "")
  end
end

---behaves like table.concat, except the separator is the first param
---and it treats empty strings as nil
---@param sep string
---@param t string[]
---@return string
local function special_concat(sep, t)
  local shift = 0
  for i = 1, #t do
    local str = t[i]
    t[i] = nil
    if str == "" then
      shift = shift + 1
    else
      t[i - shift] = str ---@type string
    end
  end
  return table.concat(t, sep)
end

local format_type

---requires data to be set already
local function populate_luts_and_maps()
  ---@param name ApiName
  local function name_selector(name) return name.name end

  -- the values rean't actually booleans after this, but who cares
  class_name_lut = linq.to_dict(data.classes, name_selector)
  event_name_lut = linq.to_dict(data.events, name_selector)
  concept_name_lut = linq.to_dict(data.concepts, name_selector)
  table_or_array_type_name_lut = linq.to_dict(
    linq.where(data.concepts, function(v)
      return v.category == "table_or_array"
    end),
    name_selector,
    function(v) ---@type ApiTableOrArrayConcept
      return sort_by_order(v.parameters)[1].type
    end)
  builtin_type_name_lut = linq.to_dict(data.builtin_types, name_selector)

  globals_map = linq.to_dict(data.global_objects, function(g)
    return format_type(g.type, function()
      print("Complex table type is not supported for global variable `"..g.name.."`.")
      return "not_supported", "not_supported"
    end)
  end)

  define_name_lut = {defines = true}
  ---@param define ApiDefine
  ---@param name_prefix string
  local function add_define(define, name_prefix)
    local name = name_prefix..define.name
    define_name_lut[name] = true
    name_prefix = name.."."
    if define.values then
      for _, value in ipairs(define.values) do
        define_name_lut[name_prefix..value.name] = true
      end
    end
    if define.subkeys then
      for _, subkey in ipairs(define.subkeys) do
        add_define(subkey, name_prefix)
      end
    end
  end
  for _, define in ipairs(data.defines) do
    add_define(define, "defines.")
  end
end

---@param reference string
---@param display_name? string
---@return string @ markdown link
local function resolve_internal_reference(reference, display_name)
  local relative_link
  if builtin_type_name_lut[reference] then
    relative_link = "Builtin-Types.html#"..reference
  elseif class_name_lut[reference] then
    relative_link = reference..".html"
  elseif event_name_lut[reference] then
    relative_link = "events.html#"..reference
  elseif define_name_lut[reference] then
    relative_link = "defines.html#"..reference
  else
    local class_name, member_name = reference:match("^(.-)::(.*)$") ---@type string
    if class_name then
      local function build_link(main) return main..".html#"..class_name.."."..member_name end
      if class_name_lut[class_name] then
        relative_link = build_link(class_name) ---@type string drunk as usual
      elseif concept_name_lut[class_name] then -- is it may be a struct?
        relative_link = build_link("Concepts")
      end -- otherwise unresolved
    elseif reference:find("Filters$") then
      if reference:find("^Lua") then
        relative_link = "Event-Filters.html#"..reference
      elseif concept_name_lut[reference] then -- the other types of filters are just concepts
        relative_link = "Concepts.html#"..reference
      end
    elseif concept_name_lut[reference] then
      relative_link = "Concepts.html#"..reference
    end
  end
  if not relative_link then
    print("Unresolved internal reference `"..reference.."`.")
    relative_link = "Unresolved_"..reference
  end
  return "["..(display_name or reference).."]("..runtime_api_base_url..relative_link..")"
end

---@param link string
---@param display_name? string
---@return string
local function resolve_link(link, display_name)
  if link:find("^http://")
    or link:find("^https://")
  then
    -- link is already an escaped url to my knowledge
    return "["..(display_name or link).."]("..link..")"
  elseif link:find("%.html$")
    or link:find("%.html#")
  then
    -- same here
    return "["..(display_name or link).."]("..runtime_api_base_url..link..")"
  else
    -- but not in this case
    return resolve_internal_reference(link, display_name)
  end
end

---@param str string
---@return string
local function resolve_all_links(str)
  local parts = {} ---@type string[]
  local prev_finish = 1
  ---@typelist number, string, string, number
  for start, name, link, finish in str:gmatch("()%[(.-)%]%((.-)%)()") do
    parts[#parts+1] = str:sub(prev_finish, start - 1)
    parts[#parts+1] = resolve_link(link, empty_to_nil(name))
    prev_finish = finish
  end
  parts[#parts+1] = str:sub(prev_finish)
  return table.concat(parts)
end

---@param reference string
---@return string
local function view_documentation(reference)
  return resolve_internal_reference(reference, "View documentation")
end

---@param description string
---@return string
local function preprocess_description(description)
  local function escape_single_newlines(str)
    return resolve_all_links(str:gsub("([^\n])\n([^\n])", function(pre, post)
      return pre.."  \n"..post
    end))
  end
  if description:find("```") then
    local result = {}
    local c = 0
    ---@param part string
    local function add(part)
      c = c + 1
      result[c] = part
    end
    local prev_finish = 1
    local in_code_block = false
    ---@param part string
    local function add_code_or_str(part)
      if in_code_block then
        add(part)
      else
        add(escape_single_newlines(part))
      end
    end
    ---@type number
    for start, finish in description:gmatch("()```()") do
      add_code_or_str(description:sub(prev_finish, start - 1))
      add("```")
      in_code_block = not in_code_block
      prev_finish = finish
    end
    add_code_or_str(description:sub(prev_finish))
    return table.concat(result)
  else
    return escape_single_newlines(description)
  end
end

---expects the current position to be a newline\
---current position will also be a newline after adding this
---@param description string
---@return string
local function convert_description(description)
  if description == "" then
    return ""
  else
    return "---"..preprocess_description(description):gsub("\n", "\n---").."\n"
  end
end

---expects the current position to be just past the type of the\
---param or return annotation\
---current position will be a newline after adding this, just like convert_description
---@param description string
---@return string
local function convert_param_or_return_description(description)
  if description == "" then
    return "\n"
  elseif is_single_line(description) then
    return "@"..preprocess_description(description).."\n"
  else
    return "@\n"..convert_description(description)
  end
end

---@param subclasses? string[]
---@return string
local function format_subclasses(subclasses)
  if subclasses then
    local length = #subclasses
    local last = subclasses[length]
    subclasses[length] = nil
    local result = "_Can only be used if this is "
      ..table.concat(subclasses, ", ")
      ..(length > 1 and " or " or "")
      ..last
      .."_"
    subclasses[length] = last -- do not leave the table modified
    return result
  else
    return ""
  end
end

---@param see_also? string[]
---@return string
local function format_see_also(see_also)
  if see_also then
    return "### See also\n"
      ---@param ref string
      ..table.concat(linq.select(see_also, function(ref)
        return "- "..resolve_internal_reference(ref)
      end), "\n")
  else
    return ""
  end
end

---@param notes? string[]
---@return string @ empty if notes are nil
local function format_notes(notes)
  if not notes then
    return ""
  end
  return table.concat(linq.select(notes, function(note)
    return "**Note:** "..note
  end), "\n\n")
end

---@param examples? string[]
---@return string @ empty if examples is nil
local function format_examples(examples)
  if not examples then
    return ""
  end
  return table.concat(linq.select(examples, function(example)
    return "### Example\n"..example
  end), "\n\n")
end

---@class format_entire_description_obj : ApiSubSeeAlso, ApiNotesAndExamples

---formats description, subclasses, see_also, notes, examples\
---even if the given object type can't even have all of these\
---initially i wrote all of these manually for every time only using whatever the type
---actually had, which tbh was just dumb.
---@param obj format_entire_description_obj
---@param view_documentation_link string
---@param description? string @ Default: obj.description
local function format_entire_description(obj, view_documentation_link, description)
  return special_concat("\n\n", {
    description or obj.description,
    format_notes(obj.notes),
    view_documentation_link,
    format_examples(obj.examples),
    format_subclasses(obj.subclasses),
    format_see_also(obj.see_also)
  })
end

local escaped_keyword_map = {} ---@type table<string, string>
for _, keyword in ipairs(lua_keywords) do
  escaped_keyword_map[keyword] = keyword.."_"
end

---adds an `_` if the given string is a lua keyword
---@param str string
---@return string
local function escape_keyword(str)
  local escaped_keyword = escaped_keyword_map[str]
  return escaped_keyword and escaped_keyword or str
end

---convert a string to a valid lua identifier
---@param str string
---@return string
local function to_id(str)
  str = str:gsub("[^a-zA-Z0-9_]", "_")
  str = str:find("^[0-9]") and "_"..str or str
  return escape_keyword(str)
end

---get eitehr `local <to_id(doc_type_name)>` or `<global_name_for_this_type>` using globals_map
---@param doc_type_name string @ for example "LuaGameScript", "LuaEntity" or "defines", etc...
---@return string
local function get_local_or_global(doc_type_name)
  local global = globals_map[doc_type_name]
  return global and global.name or "local "..to_id(doc_type_name)
end

---get the description of a global variable with for the given type if there is ones
---@param doc_type_name string
---@return string @ empty string when no global is found
local function try_get_global_description(doc_type_name)
  local global = globals_map[doc_type_name]
  return global and global.description or ""
end

---@param add fun(part: string)
---@param type_data ApiTableTypeFields
---@param table_class_name string
---@param view_documentation_link string
---@param applies_to? string @ Default: `"Applies to"`
---@return string table_class_name
local function add_table_type(add, type_data, table_class_name, view_documentation_link, applies_to)
  applies_to = applies_to or "Applies to"

  add(convert_description(view_documentation_link))
  add("---@class "..table_class_name.."\n")

  ---@type table<string, ApiParameter>
  local custom_parameter_map = {}
  ---@type ApiParameter[]
  local custom_parameters = {}

  ---@typelist integer, ApiParameter
  for i, parameter in ipairs(sort_by_order(type_data.parameters)) do
    local custom_parameter = linq.copy(parameter)
    custom_parameter_map[custom_parameter.name] = custom_parameter
    custom_parameters[i] = custom_parameter
  end

  if type_data.variant_parameter_groups then
    -- there is no good place for method.variant_parameter_description sadly
    for _, group in ipairs(type_data.variant_parameter_groups) do
      for _, parameter in ipairs(group.parameters) do

        local custom_description = applies_to.." **\""..group.name.."\"**: "
          ..(parameter.optional and "(optional)" or "(required)")
          ..extend_string{pre = "\n", str = parameter.description}

        local custom_parameter = custom_parameter_map[parameter.name]
        if custom_parameter then
          custom_parameter.description = extend_string{
            str = custom_parameter.description, post = "\n\n"
          }..custom_description
        else
          custom_parameter = linq.copy(parameter)
          custom_parameter.description = custom_description
          custom_parameter_map[parameter.name] = custom_parameter
          custom_parameters[#custom_parameters+1] = custom_parameter
        end

      end
    end
  end

  for _, custom_parameter in ipairs(custom_parameters) do
    add(convert_description(
      extend_string{str = custom_parameter.description, post = "\n\n"}
        ..view_documentation_link
    ))
    add("---@field "..custom_parameter.name.." "..format_type(custom_parameter.type, function()
      return table_class_name.."."..custom_parameter.name, view_documentation_link
    end))
    add((custom_parameter.optional and "|nil\n" or "\n"))
  end

  return table_class_name
end

local generate_table_types
do
  local complex_table_type_name_lut = {}
  local result = {nil}
  local c = 1 -- leave [1] nil for file_prefix later on
  ---@param part string
  local function add(part)
    c = c + 1
    result[c] = part
  end

  ---@param api_type ApiType
  ---@param get_table_name_and_view_doc_link fun(): string, string @
  ---get `table_class_name` and `view_documentation_link` for
  ---`add_table_type` if `api_type` is a `table` `complex_type`
  ---@param add_doc_links? boolean @ Default: `false`
  function format_type(api_type, get_table_name_and_view_doc_link, add_doc_links)
    ---@param str string
    local function wrap(str)
      if add_doc_links then
        return resolve_internal_reference(str)
      else
        return str
      end
    end
    ---@param table_name_appended_str string
    local function modify_getter(table_name_appended_str)
      return function()
        local table_class_name, view_documentation_link = get_table_name_and_view_doc_link()
        return table_class_name..table_name_appended_str, view_documentation_link
      end
    end
    if not api_type then
      print("Attempting to convert type where `api_type` is nil.")
      return "any"
    end
    if type(api_type) == "string" then
      ---@narrow api_type string
      local table_or_array_elem_type = table_or_array_type_name_lut[api_type]
      if table_or_array_elem_type then
        -- use format_type just in case it's a complex type or another `table_or_array`
        local value_type = format_type(table_or_array_elem_type, function()
          return api_type.."_elem", view_documentation(api_type)
        end, add_doc_links)
        return wrap(api_type).."<"..wrap("int")..","..value_type..">"
        -- this makes sumneko.lua think it's both the `api_type` and
        -- `table<int,value_type>` where `value_type` is the type of the first
        -- "parameter" (field) for the `table_or_array` concept
        -- it's hacks all the way
      else
        return wrap(api_type)
      end
    else
      ---@narrow api_type ApiComplexType
      if api_type.complex_type == "array" then
        return format_type(api_type.value, get_table_name_and_view_doc_link).."[]"
      elseif api_type.complex_type == "dictionary" then
        return wrap("table").."<"..format_type(api_type.key, modify_getter("_key"))
          ..","..format_type(api_type.value, modify_getter("_value"))..">"
      elseif api_type.complex_type == "variant" then
        local converted_options = {}
        for i, option in ipairs(api_type.options) do
          converted_options[i] = format_type(option, modify_getter("."..i))
        end
        return table.concat(converted_options, "|")
      elseif api_type.complex_type == "LuaLazyLoadedValue" then
        -- EmmyLua/sumneko.lua do not support generic type classes
        return wrap("LuaLazyLoadedValue").."<"..format_type(api_type.value, get_table_name_and_view_doc_link)..",nil>"
      elseif api_type.complex_type == "LuaCustomTable" then
        -- sumneko.lua doesn't actually support generic typed classes
        -- so whenever it finds a type in the format of `type<key, value>`
        -- that type gets the special treatment like `table<key, value>` would,
        -- which makes it work in for loops and with indexing for example
        -- which happens to work perfectly with LuaCustomTable
        return wrap("LuaCustomTable").."<"..format_type(api_type.key, modify_getter("_key"))
          ..","..format_type(api_type.value, modify_getter("_value"))..">"
      elseif api_type.complex_type == "table" then
        local table_class_name, view_documentation_link = get_table_name_and_view_doc_link()
        if complex_table_type_name_lut[table_class_name] then -- has it already been generated?
          return table_class_name
        else
          complex_table_type_name_lut[table_class_name] = true
          return add_table_type(add, api_type, table_class_name, view_documentation_link)
        end
      elseif api_type.complex_type == "function" then
        local i = 0
        ---@param v string
        return "fun("..table.concat(linq.select(api_type.parameters, function(v)
          i = i + 1
          local formatted_type = format_type(v, modify_getter("_param"..i))
          return "param"..i..":"..formatted_type
        end), ",")..")"
      else
        print("Unable to convert complex type `"..api_type.complex_type.."` "..serpent.line(api_type, {comment = false})..".")
        return api_type.complex_type
      end
    end
  end

  function generate_table_types()
    result[1] = file_prefix
    write_file_to_target("table_types.lua", table.concat(result))
    result = nil
    c = nil
  end
end

---expects to be just after the annotation tag, but with a space already added\
---does everything needed for param or return annotations
---@param api_type ApiType
---@param description string
---@param get_table_name_and_view_doc_link fun(): string, string
---@return string
local function convert_param_or_return(api_type, description, get_table_name_and_view_doc_link)
  return format_type(api_type, get_table_name_and_view_doc_link)..convert_param_or_return_description(description)
end

local function generate_defines()
  local result = {}
  local c = 0
  ---@param part string
  local function add(part)
    c = c + 1
    result[c] = part
  end

  add(file_prefix)
  add(convert_description(view_documentation("defines")))
  add("---@class defines\n")
  add("defines={}\n")
  ---@param define ApiDefine
  ---@param name_prefix string
  local function add_define(define, name_prefix)
    -- every define name and value name is expected to be a valid identifier
    local name = name_prefix..define.name
    add(convert_description(
      extend_string{str = define.description, post = "\n\n"}
        ..view_documentation(name)
    ))
    add("---@class "..name.."\n"..name.."={\n")
    name_prefix = name.."."
    if define.values then
      for _, value in ipairs(define.values) do
        add(convert_description(
          extend_string{str = value.description, post = "\n\n"}
            ..view_documentation(name.."."..value.name)
        ))
        add(to_id(value.name).."=0,\n")
      end
    end
    add("}\n")
    if define.subkeys then
      for _, subkey in ipairs(define.subkeys) do
        add_define(subkey, name_prefix)
      end
    end
  end
  for _, define in ipairs(data.defines) do
    add_define(define, "defines.")
  end
  write_file_to_target("defines.lua", table.concat(result))
end

local function generate_events()
  local result = {}
  local c = 0
  ---@param part string
  local function add(part)
    c = c + 1
    result[c] = part
  end
  add(file_prefix)
  for _, event in ipairs(data.events) do
    local view_documentation_link = view_documentation(event.name)
    add(convert_description(format_entire_description(event, view_documentation_link)))
    add("---@class "..event.name.."\n")
    for _, param in ipairs(event.data) do
      add(convert_description(
        extend_string{str = param.description, post = "\n\n"}
          ..view_documentation_link
      ))
      add("---@field "..param.name.." "..format_type(param.type, function()
        return event.name.."."..param.name, view_documentation_link
      end))
      add((param.optional and "|nil" or "").."\n")
    end
  end
  write_file_to_target("events.lua", table.concat(result))
end

---@param base_classes string[]
---@return string
local function convert_base_classes(base_classes)
  if base_classes then
    return ":"..table.concat(base_classes, ",")
  else
    return ""
  end
end

---@param add fun(part: string)
---@param class ApiClass|ApiStruct
---@param is_struct? boolean @ Default: `false`
local function add_class(add, class, is_struct)
  ---@param attribute ApiAttribute
  local function add_attribute(attribute)
    ---@diagnostic disable-next-line: undefined-field
    local view_doc_link = view_documentation(class.name.."::"..(attribute.html_doc_name or attribute.name))
    add(convert_description(format_entire_description(
      attribute,
      view_doc_link,
      "["..(attribute.read and "R" or "")..(attribute.write and "W" or "").."]"
        ..extend_string{pre = "\n", str = attribute.description}
    )))
    add("---@field "..attribute.name.." "..format_type(attribute.type, function()
      return class.name.."."..attribute.name, view_doc_link
    end).."\n")
  end

  ---@param method ApiMethod
  local function view_documentation_for_method(method)
    ---@diagnostic disable-next-line: undefined-field
    return view_documentation(class.name.."::"..(method.html_doc_name or method.name))
  end

  ---@param method ApiMethod
  local function add_vararg_annotation(method)
    local vararg_type = method.variadic_type
    if vararg_type then
      local vararg_description = method.variadic_description
      add("---@vararg "..format_type(vararg_type, function()
        return class.name.."."..method.name.."_vararg", view_documentation_for_method(method)
      end).."\n")
      if vararg_description ~= "" then
        local description = "\n**vararg**:"
        if is_single_line(vararg_description) then
          description = description.." "..vararg_description
        else
          description = description.."\n\n"..vararg_description
        end
        add(convert_description(description))
      end
    end
  end

  ---@param parameter ApiParameter
  ---@param method ApiMethod
  local function add_param_annontation(parameter, method)
    add("---@param "..escape_keyword(parameter.name)..(parameter.optional and "?" or " "))
    add(convert_param_or_return(parameter.type, parameter.description, function()
      return class.name.."."..method.name.."."..parameter.name, view_documentation_for_method(method)
    end))
  end

  ---@param method ApiMethod
  local function add_return_annotation(method)
    if method.return_type then
      add("---@return "..convert_param_or_return(method.return_type, method.return_description, function()
        return class.name.."."..method.name.."_return", view_documentation_for_method(method)
      end))
    end
  end



  ---@param method ApiMethod
  local function convert_description_for_method(method)
    return convert_description(format_entire_description(method, view_documentation_for_method(method)))
  end


  ---@param method ApiMethod
  local function add_regular_method(method)
    add(convert_description_for_method(method))

    ---@type ApiParameter[]
    local sorted_parameters = sort_by_order(method.parameters)
    for _, parameter in ipairs(sorted_parameters) do
      add_param_annontation(parameter)
    end
    add_vararg_annotation(method)
    add_return_annotation(method)

    ---@param parameter ApiParameter
    local name_list = linq.select(sorted_parameters, function(parameter)
      return escape_keyword(parameter.name)
    end)

    add(method.name.."=function(")
    if method.variadic_type then
      -- name_list isn't the original table, so no need to worry modifying it
      name_list[#name_list+1] = "..."
    end
    add(table.concat(name_list, ","))
    add(")end,\n")
  end


  ---@param method ApiMethod
  local function add_method_taking_table(method)
    local param_class_name = class.name.."."..method.name.."_param"
    add_table_type(add, method, param_class_name, view_documentation(class.name.."::"..method.name))
    add("\n") -- blank line needed to break apart the description for the class fields and the method
    add(convert_description_for_method(method))
    add("---@param param"..(method.table_is_optional and "?" or " ")..param_class_name.."\n")
    add_return_annotation(method)
    add(method.name.."=function(param)end,\n")
  end


  ---@param method ApiMethod
  local function add_method(method)
    if method.takes_table then
      add_method_taking_table(method)
    else
      add_regular_method(method)
    end
  end



  local needs_label = class.description ~= "" or class.notes ~= ""
  add(convert_description(format_entire_description(
    class,
    view_documentation(class.name),
    extend_string{
      pre = "**Global Description:**\n",
      str = try_get_global_description(class.name),
      post = (needs_label and "\n\n**Class Description:**\n" or "\n\n")
        ..class.description,
      fallback = class.description,
    }
  )))
  add("---@class "..class.name..convert_base_classes(class.base_classes).."\n")

  if not is_struct then
    for _, operator in ipairs(class.operators) do
      if operator.name ~= "index"
        and operator.name ~= "length"
        and operator.name ~= "call"
      then
        print("Unknown operator `"..operator.name.."` in class `"..class.name.."`.")
      end
    end
  end

  for _, attribute in ipairs(class.attributes) do
    add_attribute(attribute)
  end

  if not is_struct then
    for _, operator in ipairs(class.operators) do
      if operator.name == "index" or operator.name == "length" then
        local operator_copy = linq.copy(operator) ---@type ApiAttributeOperator
        operator_copy.name = operator.name == "index" and "__index" or "__len"
        operator_copy.html_doc_name = "operator%20"
          ..(operator.name == "index" and "[]" or "#")
        add_attribute(operator_copy)
      end
    end

    add(get_local_or_global(class.name).."={\n")
    for _, method in ipairs(class.methods) do
      add_method(method)
    end

    for _, operator in ipairs(class.operators) do
      if operator.name == "call" then
        local operator_copy = linq.copy(operator) ---@type ApiMethodOperator
        operator_copy.name = "__call"
        operator_copy.html_doc_name = "operator%20()"
        add_method(operator_copy)
      end
    end
    add("}")
  end
end

local function generate_classes()
  for _, class in ipairs(data.classes) do
    local result = {}
    local c = 0
    ---@param part string
    local function add(part)
      c = c + 1
      result[c] = part
    end
    add(file_prefix)
    add_class(add, class)
    write_file_to_target(to_id(class.name)..".lua", table.concat(result))
  end
end

local function generate_concepts()
  local result = {}
  local c = 0
  ---@param part string
  local function add(part)
    c = c + 1
    result[c] = part
  end

  ---@param union ApiUnion
  local function add_union(union)
    local view_documentation_link = view_documentation(union.name)
    local sorted_options = sort_by_order(union.options)
    local function get_table_name_and_view_doc_link(option)
      return union.name.."."..(option.order + 1), view_documentation_link
    end
    add(convert_description(format_entire_description(
      union,
      view_documentation_link,
      extend_string{str = union.description, post = "\n\n"}
        .."May be specified in one of the following ways:"
        ---@param option ApiOption
        ..table.concat(linq.select(sorted_options, function(option)
          return "\n- "
            ..format_type(option.type, function()
              return get_table_name_and_view_doc_link(option)
            end, true)
            ..extend_string{pre = ": ", str = option.description}
        end))
    )))
    add("---@class "..union.name..":")
    ---@param option ApiOption
    add(table.concat(linq.select(sorted_options, function(option)
      return format_type(option.type, function()
        return get_table_name_and_view_doc_link(option)
      end)
    end), ","))
    add("\n")
  end

  ---@param concept ApiConcept
  local function add_concept(concept)
    add(convert_description(format_entire_description(concept, view_documentation(concept.name))))
    add("---@class "..concept.name.."\n")
  end

  ---@param struct ApiStruct
  local function add_struct(struct)
    add_class(add, struct, true)
  end

  ---@param flag ApiFlag
  local function add_flag(flag)
    local view_documentation_link = view_documentation(flag.name)
    add(convert_description(format_entire_description(flag, view_documentation_link)))
    add("---@class "..flag.name.."\n")
    for _, option in ipairs(flag.options) do
      add(convert_description(
        extend_string{str = option.description, post = "\n\n"}
          ..view_documentation_link
      ))
      add("---@field "..option.name.." boolean|nil\n")
    end
  end

  ---@param table_concept ApiTableConcept
  local function add_table_concept(table_concept)
    add_table_type(add, table_concept, table_concept.name, view_documentation(table_concept.name))
  end

  ---@param table_or_array_concept ApiTableConcept
  local function add_table_or_array_concept(table_or_array_concept)
    add_table_type(add, table_or_array_concept, table_or_array_concept.name, view_documentation(table_or_array_concept.name))
  end

  ---@param enum ApiEnum
  local function add_enum(enum)
    add(convert_description(format_entire_description(
      enum,
      view_documentation(enum.name),
      special_concat("\n\n", {
        enum.description,
        "Possible values are:"
          ---@param option ApiName
          ..table.concat(linq.select(sort_by_order(enum.options), function(option)
            return "\n- \""..option.name.."\""..extend_string{pre = " - ", str = option.description}
          end))
      })
    )))
    add("---@class "..enum.name.."\n")
  end

  ---@param filter ApiFilter
  local function add_filter(filter)
    add_table_type(add, filter, filter.name, view_documentation(filter.name), "Applies to filter")
  end

  add(file_prefix)

  for _, concept in ipairs(data.concepts) do
    if concept.category == "union" then
      add_union(concept)
    elseif concept.category == "concept" then
      add_concept(concept)
    elseif concept.category == "struct" then
      add_struct(concept)
    elseif concept.category == "flag" then
      add_flag(concept)
    elseif concept.category == "table" then
      add_table_concept(concept)
    elseif concept.category == "table_or_array" then
      add_table_or_array_concept(concept)
    elseif concept.category == "enum" then
      add_enum(concept)
    elseif concept.category == "filter" then
      add_filter(concept)
    else
      print("Unknown concept category '"..concept.category.."' for concept '"..concept.name.."'.")
      add(convert_description(format_entire_description(concept, view_documentation(concept.name))))
      add("---@class "..concept.name.."\n")
    end
  end

  write_file_to_target("concepts.lua", table.concat(result))
end

local function generate_builtin()
  local result = {}
  local c = 0
  ---@param part string
  local function add(part)
    c = c + 1
    result[c] = part
  end

  add(file_prefix)

  for _, builtin_type in ipairs(data.builtin_types) do
    if not (
      builtin_type.name == "string"
      or builtin_type.name == "boolean"
      or builtin_type.name == "table"
    )
    then
      add(convert_description(
        extend_string{str = builtin_type.description, post = "\n\n"}
          ..view_documentation(builtin_type.name)
      ))
      add("---@class "..builtin_type.name..":number\n")
    end
  end

  write_file_to_target("builtin.lua", table.concat(result))
end

local function generate_custom()
  write_file_to_target("custom.lua", file_prefix..file.read_all_text(Path.new("custom.lua")))
end

---@param _args Args
---@param _data ApiFormat
local function generate(_args, _data)
  args = _args
  set_file_prefix()
  data = _data
  populate_luts_and_maps()
  valid_target_files = {}
  runtime_api_base_url = "https://lua-api.factorio.com/"..args.factorio_version.."/"
  generate_builtin()
  generate_defines()
  generate_events()
  generate_classes()
  generate_concepts()
  generate_custom()
  delete_invalid_files_from_target()
  generate_table_types()
  args = nil
  file_prefix = nil
  data = nil
  globals_map = nil
  class_name_lut = nil
  event_name_lut = nil
  define_name_lut = nil
  concept_name_lut = nil
  valid_target_files = nil
  runtime_api_base_url = nil
end

return {
  generate = generate,
}

-- fix semantics