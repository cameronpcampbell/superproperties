--!strict
--!nolint LocalShadow

local Packages = script.Parent.Parent.Parent

local Fusion = require(Packages.fusion)
local Children, Computed, New, Observer, OnChange, Peek =
    Fusion.Children, Fusion.Computed, Fusion.New,
    Fusion.Observer, Fusion.OnChange, Fusion.peek

local Utils = script.Parent.Parent.utils

local FusionUtils = require(Utils.fusionUtils)
local Component = FusionUtils.Component

local TableUtils = require(Utils.tableUtils)
local TableExtract = TableUtils.Extract

local Components = script.Parent
local Scrollable = require(Components.scrollable)
local Map = require(Components.map)

type MapProps = Map.MapProps

type MapMeasurement = {
    Root: GuiObject,
    Position: Fusion.Value<Vector2>,
    Size: Fusion.Value<Vector2>
}

type VirtualMapScrollableProps = {
    Maps: Fusion.UsedAs<{ MapProps }>,
    Overdraw: Fusion.UsedAs<number>?
}

local MapPadding = 4
local DefaultOverdraw = 200

return Component<<VirtualMapScrollableProps>>(function(scope, props)
    local props, mapsProps = TableExtract(props, "Maps")
    local props, overdraw = TableExtract(props, "Overdraw")

    local viewportAbsolutePositionState =
        Fusion.Value<<Vector2>>(scope, Vector2.new(0, 0))
    local viewportAbsoluteSizeState =
        Fusion.Value<<Vector2>>(scope, Vector2.new(0, 0))
    local canvasContentSizeState =
        Fusion.Value<<Vector2>>(scope, Vector2.new(0, 0))

    local overdrawState: Fusion.UsedAs<number> = overdraw or DefaultOverdraw

    local computeSortedMapsProps = Computed(scope, function(use, scope)
        local usedMapsProps =
            table.clone(use<<{ MapProps }>>(mapsProps :: any))

        table.sort(usedMapsProps, function(a: MapProps, b: MapProps): boolean
            return ((a :: any).LayoutOrder or 0) < ((b :: any).LayoutOrder or 0)
        end)

        return usedMapsProps
    end)

    local computeCanvasSize = Computed(scope, function(use): UDim2
        local usedMapsProps = use<<{ MapProps }>>(computeSortedMapsProps)
        if #usedMapsProps == 0 then return UDim2.new() end

        local usedCanvasContentSize =
            use<<Vector2>>(canvasContentSizeState)

        return UDim2.fromOffset(0, usedCanvasContentSize.Y)
    end)

    local computeMapInstances = Computed(scope, function(
        use,
        scope: Fusion.Scope
    )
        local usedMapsProps = use<<{ MapProps }>>(computeSortedMapsProps)
        local mapChildren =
            table.create(#usedMapsProps + 1) :: { Fusion.Child }
        local measurements =
            table.create(#usedMapsProps) :: { MapMeasurement }

        local geometryReadyState =
            Fusion.Value<<boolean>>(scope, false)

        for idx, mapProps in usedMapsProps do
            local mapAbsolutePositionState =
                Fusion.Value<<Vector2>>(scope, Vector2.new(0, 0))
            local mapAbsoluteSizeState =
                Fusion.Value<<Vector2>>(scope, Vector2.new(0, 0))

            local mapInstance = Map(scope, mapProps, {
                [Fusion.Out "AbsolutePosition"] = mapAbsolutePositionState,
                [Fusion.Out "AbsoluteSize"] = mapAbsoluteSizeState,

                VirtualListData = {
                    GeometryReady = geometryReadyState,
                    ViewportAbsolutePosition = viewportAbsolutePositionState,
                    ViewportAbsoluteSize = viewportAbsoluteSizeState,
                    MapAbsolutePosition = mapAbsolutePositionState,
                    MapAbsoluteSize = mapAbsoluteSizeState,
                    Overdraw = overdrawState
                }
            }) :: GuiObject

            mapChildren[idx] = mapInstance
            measurements[idx] = {
                Root = mapInstance,
                Position = mapAbsolutePositionState,
                Size = mapAbsoluteSizeState
            }
        end

        local layoutHasRun = false

        local function commitGeometry()
            if not layoutHasRun or Peek<<boolean>>(geometryReadyState) then
                return
            end

            local viewportAbsoluteSize =
                Peek<<Vector2>>(viewportAbsoluteSizeState)

            if viewportAbsoluteSize.X <= 0 or viewportAbsoluteSize.Y <= 0 then
                return
            end

            for _, measurement in measurements do
                if measurement.Root.Parent == nil
                    or measurement.Root:FindFirstAncestorWhichIsA(
                        "LayerCollector"
                    ) == nil
                then
                    return
                end
            end

            -- Commit every rectangle before opening the gate so no map can
            -- evaluate against a mixture of pre- and post-layout geometry.
            for _, measurement in measurements do
                measurement.Position:set(measurement.Root.AbsolutePosition)
                measurement.Size:set(measurement.Root.AbsoluteSize)
            end

            geometryReadyState:set(true)
        end

        Observer(scope, viewportAbsoluteSizeState):onChange(commitGeometry)
        Observer(scope, viewportAbsolutePositionState):onChange(commitGeometry)

        mapChildren[#usedMapsProps + 1] = New(scope, "UIListLayout") {
            FillDirection = Enum.FillDirection.Vertical,
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, MapPadding),

            [OnChange "AbsoluteContentSize"] = function(
                absoluteContentSize: Vector2
            )
                canvasContentSizeState:set(absoluteContentSize)
                layoutHasRun = true
                commitGeometry()
            end
        }

        return mapChildren
    end)

    return Scrollable(scope, {
        CanvasSize = computeCanvasSize,
        AutomaticCanvasSize = Enum.AutomaticSize.None,
        OutAbsolutePosition = viewportAbsolutePositionState,
        OutAbsoluteSize = viewportAbsoluteSizeState,

        [Children] = computeMapInstances
    }, props :: any)
end)
