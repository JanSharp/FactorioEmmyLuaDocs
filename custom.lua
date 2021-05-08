
-- This list is no longer accurate but i don't consider it worth keeping it up to date
-- until all or most of the concepts/adhoc types are dealt with/done

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

-- The rest are intentional:

---Any basic type, so like `any` but without LuaObjects.\
---This is also usesd for what we usually know as the Tags concept.
---@class AnyBasic

-- new ones that are probably new concepts that i don't have access to
-- so there are no comments with their locations

---@class PathfinderWaypoint
---@class EventData
---@class NthTickEventData
---@class BlueprintEntity
---@class CircuitConnectionSpecification
---@class FluidBoxFilter
---@class FluidBoxFilterSpec
---@class ChartTagSpec
---@class HeatConnection
---@class BlueprintSignalIcon
---@class BlueprintItemIcon
---@class Alert
---@class CutsceneWaypoint
---@class InserterCircuitConditions
---@class TechnologyModifier
