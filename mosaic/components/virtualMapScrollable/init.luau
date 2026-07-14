--!strict
--!nolint LocalShadow

local Packages = script.Parent.Parent.Parent

local Fusion = require(Packages.fusion)
local Children, Computed, Peek =
    Fusion.Children, Fusion.Computed, Fusion.peek

local Utils = script.Parent.Parent.utils

local FusionUtils = require(Utils.fusionUtils)
local Component = FusionUtils.Component

local ThemeUtils = require(Utils.themeUtils)
local GetThemeForScope = ThemeUtils.GetThemeForScope

local TableUtils = require(Utils.tableUtils)
local TableExtract = TableUtils.Extract

local Components = script.Parent
local Scrollable = require(Components.scrollable)
local Map = require(Components.map)

local VirtualListHelpers = require(Components.map.virtualListHelpers)
local CalculateMapRowCount, CalculateMapHeight =
    VirtualListHelpers.CalculateMapRowCount,
    VirtualListHelpers.CalculateMapHeight

type MapProps = Map.MapProps

type VirtualMapScrollableProps = {
    Maps: Fusion.UsedAs<{ MapProps }>
}

local MapPadding = 4

return Component<<VirtualMapScrollableProps>>(function(scope, props)
    local theme = Peek<<ThemeUtils.Theme>>(GetThemeForScope(scope))
    local lgHeight = theme:GetHeight("Lg")

    local props, mapsProps = TableExtract(props, "Maps")

    local viewportAbsolutePositionState =
        Fusion.Value<<Vector2>>(scope, Vector2.new(0, 0))
    local viewportAbsoluteSizeState =
        Fusion.Value<<Vector2>>(scope, Vector2.new(0, 0))

    local computeSortedMapsProps = Computed(scope, function(use, scope)
        local usedMapsProps =
            table.clone(use<<{ MapProps }>>(mapsProps :: any))

        table.sort(usedMapsProps, function(a: MapProps, b: MapProps): boolean
            return ((a :: any).LayoutOrder or 0) < ((b :: any).LayoutOrder or 0)
        end)

        return usedMapsProps
    end)

    local computeCanvasHeight = Computed(scope, function(use, scope): number
        local usedMapsProps = use<<{ MapProps }>>(computeSortedMapsProps)
        local mapCount = #usedMapsProps
        local canvasHeight = 0

        for idx, mapProps in usedMapsProps do
            local items = mapProps.Items
            local usedItems = if items then use<<Map.Items>>(items) else nil

            local collapsed = mapProps.Collapsed
            local usedCollapsed =
                if collapsed then use<<boolean>>(collapsed) else false

            local rowCount = CalculateMapRowCount(
                if usedItems then #usedItems else 0,
                mapProps.Header ~= nil,
                mapProps.EmptyText ~= nil
            )

            local mapHeight =
                if usedCollapsed then lgHeight
                else CalculateMapHeight(rowCount, lgHeight)

            canvasHeight += mapHeight

            if idx < mapCount then
                canvasHeight += MapPadding
            end
        end

        return canvasHeight
    end)

    local computeMapInstances = Computed(scope, function(
        use,
        scope: Fusion.Scope
    )
        local usedMapsProps = use<<{ MapProps }>>(computeSortedMapsProps)
        local mapsInstances = table.create(#usedMapsProps)

        for idx, mapProps in usedMapsProps do
            local mapAbsolutePositionState =
                Fusion.Value<<Vector2>>(scope, Vector2.new(0, 0))
            local mapAbsoluteSizeState =
                Fusion.Value<<Vector2>>(scope, Vector2.new(0, 0))

            mapsInstances[idx] = Map(scope, mapProps, {
                [Fusion.Out "AbsolutePosition"] = mapAbsolutePositionState,
                [Fusion.Out "AbsoluteSize"] = mapAbsoluteSizeState,

                VirtualListData = {
                    ViewportAbsolutePosition = viewportAbsolutePositionState,
                    ViewportAbsoluteSize = viewportAbsoluteSizeState,
                    MapAbsolutePosition = mapAbsolutePositionState,
                    MapAbsoluteSize = mapAbsoluteSizeState
                }
            })
        end

        return mapsInstances
    end)

    return Scrollable(scope, {
        CanvasSize = FusionUtils.ComputeTransforms.UDim2(
            scope,
            UDim.new(),
            FusionUtils.ComputeTransforms.UDim(scope, 0, computeCanvasHeight)
        ),
        AutomaticCanvasSize = Enum.AutomaticSize.None,
        OutAbsolutePosition = viewportAbsolutePositionState,
        OutAbsoluteSize = viewportAbsoluteSizeState,

        [Children] = computeMapInstances
    }, props :: any)
end)
