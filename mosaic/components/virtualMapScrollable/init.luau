--!strict
--!nolint LocalShadow

local Packages = script.Parent.Parent.Parent

local Fusion = require(Packages.fusion)
local Children, Computed, Observer, Peek =
    Fusion.Children, Fusion.Computed,
    Fusion.Observer, Fusion.peek

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
    Overdraw: Fusion.UsedAs<number>?,
    Padding: Fusion.UsedAs<number>?
}

local DefaultPadding = 4
local DefaultOverdraw = 200

return Component<<VirtualMapScrollableProps>>(function(scope, props)
    local props, mapsProps = TableExtract(props, "Maps")
    local props, overdraw = TableExtract(props, "Overdraw")
    local props, padding = TableExtract(props, "Padding", DefaultPadding)

    local viewportAbsolutePositionState =
        Fusion.Value<<Vector2>>(scope, Vector2.new(0, 0))
    local viewportAbsoluteSizeState =
        Fusion.Value<<Vector2>>(scope, Vector2.new(0, 0))
    local canvasHeightState = Fusion.Value<<number>>(scope, 0)

    local overdrawState: Fusion.UsedAs<number> = overdraw or DefaultOverdraw
    local paddingState: Fusion.UsedAs<number> = padding

    local computeSortedMapsProps = Computed(scope, function(use, scope)
        local usedMapsProps =
            table.clone(use<<{ MapProps }>>(mapsProps :: any))

        table.sort(usedMapsProps, function(a: MapProps, b: MapProps): boolean
            return ((a :: any).LayoutOrder or 0) < ((b :: any).LayoutOrder or 0)
        end)

        return usedMapsProps
    end)

    local computeCanvasSize = Computed(scope, function(use): UDim2
        return UDim2.fromOffset(0, use<<number>>(canvasHeightState))
    end)

    local computeMapInstances = Computed(scope, function(
        use,
        scope: Fusion.Scope
    )
        local usedMapsProps = use<<{ MapProps }>>(computeSortedMapsProps)
        local mapChildren = table.create(#usedMapsProps) :: { Fusion.Child }
        local measurements =
            table.create(#usedMapsProps) :: { MapMeasurement }

        local geometryReadyState =
            Fusion.Value<<boolean>>(scope, false)
        local commitGeometry: () -> () = function() end
        -- Each map is positioned from the previous map's live tweened bottom.
        local previousBottom: Fusion.UsedAs<number>? = nil

        for idx, mapProps in usedMapsProps do
            local mapAbsolutePositionState =
                Fusion.Value<<Vector2>>(scope, Vector2.new(0, 0))
            local mapAbsoluteSizeState =
                Fusion.Value<<Vector2>>(scope, Vector2.new(0, 0))

            local mapTop: Fusion.UsedAs<number> = 0

            if previousBottom then
                local priorBottom = previousBottom

                mapTop = Computed(scope, function(use): number
                    local usedPadding =
                        math.max(use<<number>>(paddingState), 0)

                    return use<<number>>(priorBottom) + usedPadding
                end)
            end

            local mapPosition = Computed(scope, function(use): UDim2
                return UDim2.fromOffset(0, use<<number>>(mapTop))
            end)

            local mapInstance = Map(scope, mapProps, {
                Position = mapPosition,
                AnchorPoint = Vector2.new(0, 0),

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

            table.insert(
                scope,
                mapInstance:GetPropertyChangedSignal("Parent"):Connect(
                    function()
                        commitGeometry()
                    end
                )
            )

            previousBottom = Computed(scope, function(use): number
                local usedMapSize = use<<Vector2>>(mapAbsoluteSizeState)

                return use<<number>>(mapTop) + usedMapSize.Y
            end)
        end

        local finalBottom = previousBottom

        if finalBottom then
            -- The last bottom is the complete canvas height without trailing
            -- padding, and changes throughout collapse/expand tweens.
            local function publishCanvasHeight()
                canvasHeightState:set(Peek<<number>>(finalBottom))
            end

            Observer(scope, finalBottom):onChange(publishCanvasHeight)
            publishCanvasHeight()
        else
            canvasHeightState:set(0)
        end

        commitGeometry = function()
            if Peek<<boolean>>(geometryReadyState) then return end

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
