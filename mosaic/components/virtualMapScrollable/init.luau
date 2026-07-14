--!strict
--!nolint LocalShadow

local Packages = script.Parent.Parent.Parent
local Typeforge = require(Packages.typeforge)

local Fusion = require(Packages.fusion)
local Children, Computed = Fusion.Children, Fusion.Computed

local Utils = script.Parent.Parent.utils

local FusionUtils = require(Utils.fusionUtils)
local Component = FusionUtils.Component

local TableUtils = require(Utils.tableUtils)
local TableExtract = TableUtils.Extract

local Components = script.Parent
local Scrollable = require(Components.scrollable)
local Map = require(Components.map)

type MapProps = Typeforge.Omit<Map.MapProps, "VirtualList">

type VirtualMapScrollableProps = {
    Maps: Fusion.UsedAs<{ MapProps }>
}

return Component<<VirtualMapScrollableProps>>(function(scope, props)
    local props, mapsProps = TableExtract<<>>(props, "Maps")

    local computeMapInstances = Computed(scope, function(use, scope)
        local usedMapsProps = use<<{MapProps}>>(mapsProps)
        local mapsInstances = table.create(#usedMapsProps)

        for idx, mapProps in usedMapsProps do
            mapsInstances[idx] = Map(scope, mapProps)
        end

        return mapsInstances
    end)

    return Scrollable(scope, {
        [Children] = computeMapInstances
    }, props :: any)
end)
