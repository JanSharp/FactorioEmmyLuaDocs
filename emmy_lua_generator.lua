
local lfs = require("lfs") ---@type LFS
local file = require("file")
local Path = require("path")
local serpent = require("serpent")
local linq = require("linq")

local lua_keywords = require("lua_keywords")
local concept_names = require("concept_names")

local args ---@type Args
local data ---@type ApiFormat
---indexed by converted types
local globals_map ---@type table<string, ApiGlobalVariable>
local class_name_lut ---@type table<string, boolean>
local event_name_lut ---@type table<string, boolean>
local define_name_lut ---@type table<string, boolean>
local builtin_type_name_lut ---@type table<string, boolean>
local concept_name_lut ---@type table<string, boolean>
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

local convert_type

---requires data to be set already
local function populate_luts_and_maps()
  ---@param name ApiName
  local function name_selector(name) return name.name end
  ---@param name string
  local function basic_name_selector(name) return name end

  -- the values rean't actually booleans after this, but who cares
  class_name_lut = linq.to_dict(data.classes, name_selector)
  event_name_lut = linq.to_dict(data.events, name_selector)
  concept_name_lut = linq.to_dict(concept_names, basic_name_selector)
  builtin_type_name_lut = linq.to_dict(data.builtin_types, name_selector)

  globals_map = linq.to_dict(data.global_variables, function(g)
    return convert_type(g.type)
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
      relative_link = class_name..".html#"..class_name.."."..member_name
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
    print("Unresolved internal reference `"..reference.."`. Missing hardcoded concept in concept_names.lua?")
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

---May also take an ApiSubSeeAlso as a single parameter
---@param description string
---@param subclasses string[]|nil @ which subclasses this can be used on
---@param see_also string[]|nil @ references to members of other classes
local function convert_description_sub_see_also(description, subclasses, see_also)
  if type(description) == "table" then
    local sub_see_also = description ---@type ApiSubSeeAlso
    description = sub_see_also.description
    subclasses = sub_see_also.subclasses
    see_also = sub_see_also.see_also
  end

  local result = {empty_to_nil(description)}

  if subclasses then
    local length = #subclasses
    local last = subclasses[length]
    subclasses[length] = nil
    result[#result+1] = "_Can only be used if this is "
      ..table.concat(subclasses, ", ")
      ..(length > 1 and "or " or "")
      ..last
      .."_"
    subclasses[length] = last -- do not leave the table modified
  end

  if see_also then
    result[#result+1] = "### See also\n"
      ---@param ref string
      ..table.concat(linq.select(see_also, function(ref)
        return "- "..resolve_internal_reference(ref)
      end), "\n")
  end

  return convert_description(table.concat(result, "\n\n"))
end

---@param notes? string[]
---@return string @ empty if notes are nil
local function format_notes(notes)
  if not notes then
    return ""
  end
  return table.concat(linq.select(notes, function(note)
    return "**Note:**: "..note
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

---@param api_type ApiType
function convert_type(api_type)
  if not api_type then
    -- print("Attempting to convert type where `api_type` is nil.")
    return "any"
  end
  if type(api_type) == "string" then
    ---@narrow api_type string
    return api_type == "function" and "fun()" or api_type:gsub(" ", "-")
  else
    ---@narrow api_type ApiComplexType
    if api_type.complex_type == "array" then
      return convert_type(api_type.value).."[]"
    elseif api_type.complex_type == "dictionary" then
      return "table<"..convert_type(api_type.key)
        ..","..convert_type(api_type.value)..">"
    elseif api_type.complex_type == "variant" then
      local converted_options = {}
      for i, option in ipairs(api_type.options) do
        converted_options[i] = convert_type(option)
      end
      return table.concat(converted_options, "|")
    elseif api_type.complex_type == "LuaLazyLoadedValue" then
      -- EmmyLua/sumneko.lua do not support generic type classes
      return "LuaLazyLoadedValue<"..convert_type(api_type.value)..",nil>"
    elseif api_type.complex_type == "LuaCustomTable" then
      -- sumneko.lua doesn't actually support generic typed classes
      -- so whenever it finds a type in the format of `type<key, value>`
      -- that type gets the special treatment like `table<key, value>` would,
      -- which makes it work in for loops and with indexing for example
      -- which happens to work perfectly with LuaCustomTable
      return "LuaCustomTable<"..convert_type(api_type.key)
        ..","..convert_type(api_type.value)..">"
    elseif api_type.complex_type == "table" then
      print("table!")
      return "table"
    elseif api_type.complex_type == "function" then
      ---@param v string
      return "fun("..table.concat(linq.select(api_type.parameters, function(v) return to_id(v)..":"..to_id(v) end), ",")..")"
    else
      print("Unable to convert complex type `"..api_type.complex_type.."` "..serpent.line(api_type, {comment = false})..".")
      return api_type.complex_type
    end
  end
end

---expects to be just after the annotation tag, but with a space already added\
---does everything needed for param or return annotations
---@param api_type ApiType
---@param description string
---@return string
local function convert_param_or_return(api_type, description)
  return convert_type(api_type)..convert_param_or_return_description(description)
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
    add(convert_description(
      extend_string{str = event.description, post = "\n\n"}
        ..extend_string{str = format_notes(event.notes), post = "\n\n"}
        ..view_documentation(event.name)
        ..extend_string{pre = "\n\n", str = format_examples(event.examples)}
    ))
    add("---@class "..event.name.."\n")
    for _, param in ipairs(event.data) do
      add(convert_description(
        extend_string{str = param.description, post = "\n\n"}
          ..view_documentation(event.name)
      ))
      add("---@field "..param.name.." "..convert_type(param.type))
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

local function generate_classes()
  for _, class in ipairs(data.classes) do
    local result = {}
    local c = 0
    ---@param part string
    local function add(part)
      c = c + 1
      result[c] = part
    end


    ---@param attribute ApiAttribute
    local function add_attribute(attribute)
      add(convert_description_sub_see_also(
        "["..(attribute.read and "R" or "")..(attribute.write and "W" or "").."]"
        ..extend_string{pre = "\n", str = attribute.description}
        .."\n\n"
        ..extend_string{str = format_notes(attribute.notes), post = "\n\n"}
        ---@diagnostic disable-next-line: undefined-field
        ..view_documentation(class.name.."::"..(attribute.html_doc_name or attribute.name))
        ..extend_string{pre = "\n\n", str = format_examples(attribute.examples)},

        attribute.subclasses,
        attribute.see_also
      ))
      add("---@field "..attribute.name.." "..convert_type(attribute.type).."\n")
    end

    ---@param parameter ApiParameter
    local function add_vararg_annotation(parameter)
      add("---@vararg "..convert_type(parameter.type).."\n")
      if parameter.description ~= "" then
        local description = "\n**vararg**:"
        if is_single_line(parameter.description) then
          description = description.." "..parameter.description
        else
          description = description.."\n\n"..parameter.description
        end
        add(convert_description(description))
      end
    end

    ---@param parameter ApiParameter
    local function add_param_annontation(parameter)
      add("---@param "..escape_keyword(parameter.name)..(parameter.optional and "?" or " "))
      add(convert_param_or_return(parameter.type, parameter.description))
    end

    ---@param method ApiMethod
    local function add_return_annotation(method)
      if method.return_type then
        add("---@return "..convert_param_or_return(method.return_type, method.return_description))
      end
    end


    ---@param method ApiMethod
    local function convert_description_for_method(method)
      return convert_description_sub_see_also(
        extend_string{str = method.description, post = "\n\n"}
          ..extend_string{str = format_notes(method.notes), post = "\n\n"}
          ---@diagnostic disable-next-line: undefined-field
          ..view_documentation(class.name.."::"..(method.html_doc_name or method.name))
          ..extend_string{pre = "\n\n", str = format_examples(method.examples)},
        method.subclasses,
        method.see_also
      )
    end


    ---@param method ApiMethod
    local function add_regular_method(method)
      add(convert_description_for_method(method))

      ---@type ApiParameter[]
      local sorted_parameters = sort_by_order(method.parameters)
      for _, parameter in ipairs(sorted_parameters) do
        if parameter.name == "..." then
          add_vararg_annotation(parameter)
        else
          add_param_annontation(parameter)
        end
      end
      add_return_annotation(method)

      ---@param parameter ApiParameter
      local name_list = linq.select(sorted_parameters, function(parameter)
        return escape_keyword(parameter.name)
      end)

      add(method.name.."=function(")
      add(table.concat(name_list, ","))
      add(")end,\n")
    end


    ---@param method ApiMethod
    local function add_method_taking_table(method)
      local param_class_name = class.name.."."..method.name.."_param"
      add("---@class "..param_class_name.."\n")

      ---@type table<string, ApiParameter>
      local custom_parameter_map = {}
      ---@type ApiParameter[]
      local custom_parameters = {}

      ---@typelist integer, ApiParameter
      for i, parameter in ipairs(sort_by_order(method.parameters)) do
        local custom_parameter = linq.copy(parameter)
        custom_parameter_map[custom_parameter.name] = custom_parameter
        custom_parameters[i] = custom_parameter
      end

      if method.variant_parameter_groups then
        -- there is no good place for method.variant_parameter_description sadly
        for _, group in ipairs(method.variant_parameter_groups) do
          for _, parameter in ipairs(group.parameters) do

            local custom_description = "Applies to **"..group.name.."**: "
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

      local view_documentation_link = view_documentation(class.name.."::"..method.name)
      for _, custom_parameter in ipairs(custom_parameters) do
        add(convert_description(
          extend_string{str = custom_parameter.description, post = "\n\n"}
            ..view_documentation_link
        ))
        add("---@field "..custom_parameter.name.." "..convert_type(custom_parameter.type))
        add((custom_parameter.optional and "|nil\n" or "\n"))
      end

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



    add(file_prefix)
    local global_description = extend_string{
      pre = "**Global Description:**\n",
      str = try_get_global_description(class.name),
      post = "\n\n",
    }
    add(convert_description_sub_see_also(
      extend_string{
        pre = extend_string{
          str = global_description,
          post = "**Class Description:**\n",
        },
        str = extend_string{str = class.description, post = "\n\n"}
          ..extend_string{str = format_notes(class.notes), post = "\n\n"},
        fallback = global_description,
      }
        ..view_documentation(class.name)
        ..extend_string{pre = "\n\n", str = format_examples(class.examples)},
      class.subclasses,
      class.see_also
    ))
    add("---@class "..class.name..convert_base_classes(class.base_classes).."\n")

    for _, operator in ipairs(class.operators) do
      if operator.name ~= "index"
        and operator.name ~= "length"
        and operator.name ~= "call"
      then
        print("Unknown operator `"..operator.name.."` in class `"..class.name.."`.")
      end
    end

    for _, attribute in ipairs(class.attributes) do
      add_attribute(attribute)
    end

    for _, operator in ipairs(class.operators) do
      if operator.name == "index" or operator.name == "length" then
        local operator_copy = linq.copy(operator) ---@type ApiAttributeOperator
        operator_copy.name = operator.name == "index" and "__index" or "__len"
        operator_copy.html_doc_name = "operator%20"
          ..(operator.name == "index" and "[]" or "#") -- HACK
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
        operator_copy.html_doc_name = "operator%20()" -- HACK
        add_method(operator_copy)
      end
    end
    add("}")

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

  add(file_prefix)

  for _, concept_name in ipairs(concept_names) do
    if not (concept_name == "GameViewSettings" or concept_name == "TileProperties") then
      add(convert_description(view_documentation(concept_name)))
      add("---@class "..concept_name.."\n")
    end
  end

  add(convert_description(view_documentation("GameViewSettings")))
  add([[
---@class GameViewSettings
---@field show_controller_gui boolean [RW] Show the controller GUI elements.
---@field show_minimap boolean [RW] Show the chart in the upper right-hand corner of the screen.
---@field show_research_info boolean [RW] Show research progress and name in the upper right-hand corner of the screen.
---@field show_entity_info boolean [RW] Show overlay icons on entities.
---@field show_alert_gui boolean [RW] Show the flashing alert icons next to the player's toolbar.
---@field update_entity_selection boolean [RW] When true (the default), mousing over an entity will select it.
---@field show_rail_block_visualisation boolean [RW] When true (false is default), the rails will always show the rail block visualisation.
---@field show_side_menu boolean [RW] Shows or hides the buttons row.
---@field show_map_view_options boolean [RW] Shows or hides the view options when map is opened.
---@field show_quickbar boolean [RW] Shows or hides quickbar of shortcuts.
---@field show_shortcut_bar boolean [RW] Shows or hides the shortcut bar.
]])

  add(convert_description(view_documentation("TileProperties")))
  add([[
---@class TileProperties
---@field tier_from_start double [RW]
---@field roughness double [RW]
---@field elevation double [RW]
---@field available_water double [RW]
---@field temperature double [RW]
]])

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
  -- HACK: api_version "???" treated as "latest"
  runtime_api_base_url = "https://lua-api.factorio.com/"..(data.api_version == "???" and "latest" or data.api_version).."/"
  generate_builtin()
  generate_defines()
  generate_events()
  generate_classes()
  generate_concepts()
  generate_custom()
  delete_invalid_files_from_target()
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