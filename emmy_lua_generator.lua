
---@type LFS
local lfs = require("lfs")
local file = require("file")
local serpent = require("serpent")
local linq = require("linq")

---@type Args
local args
---@type ApiFormat
local data
---@type table<string, boolean>
local valid_target_files

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

local file_prefix = "---@meta\n---@diagnostic disable\n"

---@param description string|nil
---@return string
local function convert_description(description)
  if description == "" then
    return ""
  else
    return "---"..description:gsub("\n", "  \n---").."\n"
  end
end

---@type string[]
local keywords = {
  "and",
  "break",
  "do",
  "else",
  "elseif",
  "end",
  "false",
  "for",
  "function",
  "goto",
  "if",
  "in",
  "local",
  "nil",
  "not",
  "or",
  "repeat",
  "return",
  "then",
  "true",
  "until",
  "while",
}
---@type table<string, string>
local keyword_map = {}
for _, keyword in ipairs(keywords) do
  keyword_map[keyword] = keyword.."_"
end

---convert a string to a valid lua identifier
---@param str string
---@return string
local function to_id(str)
  str = str:gsub("[^a-zA-Z0-9_]", "_")
  str = str:find("^[0-9]") and "_"..str or str
  local escaped_keyword = keyword_map[str]
  return escaped_keyword and escaped_keyword or str
end

---@param api_type ApiType
local function convert_type(api_type)
  if not api_type then
    -- print("Attempting to convert type where `api_type` is nil.")
    return "any"
  end
  if type(api_type) == "string" then
    ---@type string
    api_type = api_type
    return api_type == "function" and "fun()" or api_type:gsub(" ", "-")
  else
    ---@type ApiComplexType
    api_type = api_type
    if api_type.type == "array" then
      return convert_type(api_type.value).."[]"
    elseif api_type.type == "dictionary" then
      return "table<"..convert_type(api_type.key)
        ..","..convert_type(api_type.value)..">"
    elseif api_type.type == "variant" then
      local converted_options = {}
      for i, option in ipairs(api_type.options) do
        converted_options[i] = convert_type(option)
      end
      return table.concat(converted_options, "|")
    elseif api_type.type == "LazyLoadedValue" then
      -- EmmyLua/sumneko.lua do not support generic type classes
      return "LuaLazyLoadedValue<"..convert_type(api_type.value)..",nil>"
    elseif api_type.type == "CustomDictionary" then
      return "LuaCustomTable<"..convert_type(api_type.key)
        ..","..convert_type(api_type.value)..">"
    elseif api_type.type == "CustomArray" then
      return "LuaCustomTable<integer,"..convert_type(api_type.value)..">"
    elseif api_type.type == "function" then
      ---@param v string
      return "fun("..table.concat(linq.select(api_type.parameters, function(v) return to_id(v)..":"..to_id(v) end), ",")..")"
    else
      print("Unable to convert complex type `"..api_type.type.."` "..serpent.line(api_type, {comment = false})..".")
      return api_type.type
    end
  end
end

local function generate_defines()
  local result = {}
  local c = 0
  ---@param part string
  local function add(part)
    c = c + 1
    result[c] = part
  end
  add(file_prefix.."---@class defines\ndefines={}\n")
  ---@param define ApiDefine
  ---@param name_prefix string
  local function add_define(define, name_prefix)
    -- every define name and value name is expected to be a valid identifier
    local name = name_prefix..define.name
    add(convert_description(define.description)
      .."---@class "..name.."\n"..name.."={\n")
    name_prefix = name.."."
    if define.values then
      for _, value in ipairs(define.values) do
        add(convert_description(value.description)
          ..to_id(value.name).."=0,\n")
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
    add(convert_description(event.description)
      .."---@class "..event.name.."\n")
    for _, param in ipairs(event.data) do
      add(convert_description(param.description)
        .."---@field "..param.name.." "..convert_type(param.type)
        ..(param.optional and "|nil" or "").."\n")
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
    add(file_prefix
      ..convert_description(class.description)
      .."---@class "..class.name..convert_base_classes(class.base_classes).."\n")
    -- TODO: see_also and subclasses
    for _, attribute in ipairs(class.attributes) do
      if attribute.name:find("^operator") then -- TODO: operators
        -- print(class.name.."::"..attribute.name)
      else
        add(convert_description("["..(attribute.read and "R" or "")..(attribute.write and "W" or "").."]"
          ..(attribute.description and attribute.description ~= "" and "\n"..attribute.description or "")) -- TODO: code duplication
          .."---@field "..attribute.name.." "..convert_type(attribute.type).."\n")
        -- TODO: see_also and subclasses
      end
    end
    add("local "..to_id(class.name).."={\n")
    for _, method in ipairs(class.methods) do
      if method.name:find("^operator") then -- TODO: operators
        -- print(class.name.."::"..method.name)
      elseif method.takes_table then -- method that takes a table
        local arg_class_name = class.name.."."..method.name.."_param"
        add("---@class "..arg_class_name.."\n")
        -- TODO: remove the insane amount of code duplication here
        ---@type table<string, ApiParameter>
        local parameter_map = {}
        ---@type ApiParameter[]
        local all_parameters = {}
        ---@type ApiParameter
        for _, parameter in ipairs(sort_by_order(method.parameters)) do
          parameter = linq.copy(parameter)
          parameter.description = convert_description(parameter.description)
          parameter_map[parameter.name] = parameter
          all_parameters[#all_parameters+1] = parameter
        end
        if method.variant_parameter_groups then
          -- there is no good place for method.variant_parameter_description sadly
          for _, group in ipairs(method.variant_parameter_groups) do
            for _, group_parameter in ipairs(group.parameters) do
              local parameter = parameter_map[group_parameter.name]
              if parameter then
                parameter.description = parameter.description.."---\n"
                  ..convert_description("Applies to **"..group.name.."**: "
                  ..(group_parameter.optional and "(optional)" or "(required)")
                  ..(group_parameter.description and group_parameter.description ~= "" and "\n"..group_parameter.description or ""))
              else
                parameter = linq.copy(group_parameter)
                parameter.description = convert_description("Applies to **"..group.name.."**: "
                  ..(group_parameter.optional and "(optional)" or "(required)")
                  ..(parameter.description and parameter.description ~= "" and "\n"..parameter.description or ""))
                parameter_map[group_parameter.name] = parameter
                all_parameters[#all_parameters+1] = parameter
              end
            end
          end
        end
        for _, parameter in ipairs(all_parameters) do
          add(parameter.description
            .."---@field "..parameter.name.." "..convert_type(parameter.type)
            ..(parameter.optional and "|nil" or "").."\n")
        end
        -- TODO: see_also and subclasses
        add("\n" -- blank line needed to break apart the description for the class fields and the method
          ..convert_description(method.description)
          .."---@param param "..arg_class_name.."\n")
        if method.return_type then
          add("---@return "..convert_type(method.return_type).."@\n"
            ..convert_description(method.return_description)) -- TODO: potentially missing or single line descriptions
        end
        add(method.name.."=function(param)end,\n")
      else -- regular method
        add(convert_description(method.description))
        -- TODO: see_also and subclasses
        ---@type ApiParameter[]
        local sorted_parameters = sort_by_order(method.parameters)
        for _, parameter in ipairs(sorted_parameters) do
          add("---@param "..to_id(parameter.name)..(parameter.optional and "?" or " ")
            ..convert_type(parameter.type).."@\n"..convert_description(parameter.description)) -- TODO: potentially missing or single line descriptions
        end
        if method.return_type then
          add("---@return "..convert_type(method.return_type).."@\n"
            ..convert_description(method.return_description)) -- TODO: potentially missing or single line descriptions
        end
        add(method.name.."=function("
          ..table.concat(linq.select(sorted_parameters, function(v) return to_id(v.name) end), ",")
          ..")end,\n")
      end
    end
    add("}")
    write_file_to_target(to_id(class.name)..".lua", table.concat(result))
  end
end

local function generate_basics()
  write_file_to_target("basic.lua", file_prefix..[[
---@class float : number
---@class double : number
---@class int : number
---@class int8 : number
---@class uint : number
---@class uint8 : number
---@class uint16 : number
---@class uint64 : number
]])
end

local function generate_concepts()
  write_file_to_target("concepts.lua", file_prefix..[[
---@class LocalisedString
---@class DisplayResolution
---@class PersonalLogisticParameters
---@class Position
---@class ChunkPosition
---@class TilePosition
---@class ChunkPositionAndArea
---@class GuiLocation
---@class GuiAnchor
---@class OldTileAndPosition
---@class Tags
---@class SmokeSource
---@class Vector
---@class BoundingBox
---@class ScriptArea
---@class ScriptPosition
---@class Color
---@class ColorModifier
---@class PathFindFlags
---@class MapViewSettings
---@class MapSettings
---@class DifficultySettings
---@class MapExchangeStringData
---@class Fluid
---@class Ingredient
---@class Product
---@class Loot
---@class Modifier
---@class Offer
---@class AutoplaceSpecification
---@class NoiseExpression
---@class Resistances
---@class MapGenSize
---@class AutoplaceSettings
---@class CliffPlacementSettings
---@class MapGenSettings
---@class SignalID
---@class Signal
---@class UpgradeFilter
---@class InfinityInventoryFilter
---@class InfinityPipeFilter
---@class HeatSetting
---@class FluidBoxConnection
---@class ArithmeticCombinatorParameters
---@class ConstantCombinatorParameters
---@class ComparatorString
---@class DeciderCombinatorParameters
---@class CircuitCondition
---@class CircuitConditionSpecification
---@class Filter
---@class PlaceAsTileResult
---@class RaiseEventParameters
---@class SimpleItemStack
---@class Command
---@class PathfindFlags
---@class FluidSpecification
---@class ForceSpecification
---@class TechnologySpecification
---@class SurfaceSpecification
---@class PlayerSpecification
---@class ItemStackSpecification
---@class EntityPrototypeSpecification
---@class ItemPrototypeSpecification
---@class WaitCondition
---@class TrainScheduleRecord
---@class TrainSchedule
---@class GuiArrowSpecification
---@class AmmoType
---@class BeamTarget
---@class RidingState
---@class SpritePath
---@class SoundPath
---@class ModConfigurationChangedData
---@class ConfigurationChangedData
---@class EffectValue
---@class Effects
---@class EntityPrototypeFlags
---@class ItemPrototypeFlags
---@class CollisionMaskLayer
---@class CollisionMask
---@class CollisionMaskWithFlags
---@class TriggerTargetMask
---@class TriggerEffectItem
---@class TriggerDelivery
---@class TriggerItem
---@class Trigger
---@class AttackParameters
---@class CapsuleAction
---@class SelectionModeFlags
---@class LogisticFilter
---@class ModSetting
---@class Any
---@class ProgrammableSpeakerParameters
---@class ProgrammableSpeakerAlertParameters
---@class ProgrammableSpeakerCircuitParameters
---@class ProgrammableSpeakerInstrument
---@class Alignment
---@class NthTickEvent
---@class ScriptRenderTarget
---@class MouseButtonFlags
---@class CursorBoxRenderType
---@class ForceCondition
---@class RenderLayer
---@class CliffOrientation
---@class ItemStackLocation
---@class VehicleAutomaticTargetingParameters
---@class SoundType
---@class ItemPrototypeFilters
---@class ModSettingPrototypeFilters
---@class TechnologyPrototypeFilters
---@class DecorativePrototypeFilters
---@class AchievementPrototypeFilters
---@class FluidPrototypeFilters
---@class EquipmentPrototypeFilters
---@class TilePrototypeFilters
---@class RecipePrototypeFilters
---@class EntityPrototypeFilters

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

---@class TileProperties
---@field tier_from_start double [RW]
---@field roughness double [RW]
---@field elevation double [RW]
---@field available_water double [RW]
---@field temperature double [RW]
]])
end

local function generate_custom()
  write_file_to_target("custom.lua", file_prefix..[[
---on_script_path_request_finished
---@class Waypoint

---script_raised_set_tiles
---
---LuaSurface.set_tile param tiles
---@class Tile

---LuaBootstrap.on_event param event
---@class Event

---LuaBootstrap.on_event param filters
---
---LuaBootstrap.set_event_filters param filters
---@class Filters

---LuaControl.crafting_queue
---@class CraftingQueueItem

---LuaControl.get_blueprint_entities
---
---LuaItemStack.get_blueprint_entities return
---
---LuaItemStack.set_blueprint_entities param entities
---@class blueprint-entity

---LuaItemStack.get_blueprint_tiles return
---
---LuaItemStack.set_blueprint_tiles param tiles
---@class blueprint-tile

---LuaEntity.circuit_connection_definitions
---@class CircuitConnectionDefinition

---LuaEntityPrototype.result_units
---@class UnitSpawnDefinition

---LuaGameScript.map_gen_presets
---@class MapGenPreset

---LuaGuiElement.elem_filters
---
---LuaGuiElement.add param field elem_filters
---@class PrototypeFilters

---LuaGuiElement.tabs
---@class TabAndContent

---LuaHeatEnergySourcePrototype.connections
---@class Connection

---LuaItemStack.blueprint_icons
---
---LuaItemStack.default_icons
---@class Icon

---LuaLazyLoadedValue.get return
---@class varies

---LuaPlayer.get_alerts return
---@class alert

---LuaRemote.call param ...
---@class variadic

---LuaRemote.call return
---@class Anything

---LuaRendering.draw_polygon param field vertices
---@class CustomScriptRenderTarget

---LuaSurface.create_decoratives param field decoratives
---@class Decorative

---LuaSurface.find_decoratives_filtered return
---@class DecorativeResult
]])
end

local function generate_globals()
  write_file_to_target("globals.lua", file_prefix..[[
---@type LuaGameScript
game = {}
---@type LuaBootstrap
script = {}
---@type LuaRemote
remote = {}
---@type LuaCommandProcessor
commands = {}
---@type LuaSettings
settings = {}
---@type LuaRCON
rcon = {}
---@type LuaRendering
rendering = {}
]])
end

---@param _args Args
---@param _data ApiFormat
local function generate(_args, _data)
  args = _args
  data = _data
  valid_target_files = {}
  generate_basics()
  generate_defines()
  generate_events()
  generate_classes()
  generate_concepts()
  generate_custom()
  generate_globals()
  delete_invalid_files_from_target()
  args = nil
  data = nil
  valid_target_files = nil
end

return {
  generate = generate,
}
