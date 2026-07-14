--!strict
--!nolint LocalShadow

local Packages = script.Parent.Parent.Parent

local Fusion = require(Packages.fusion)
local Children, Computed, Observer, Peek =
    Fusion.Children, Fusion.Computed, Fusion.Observer, Fusion.peek

local Utils = script.Parent.Parent.utils

local FusionUtils = require(Utils.fusionUtils)
local Component, CoerceToValue =
    FusionUtils.Component, FusionUtils.CoerceToValue

local ThemeUtils = require(Utils.themeUtils)
local GetThemeForScope = ThemeUtils.GetThemeForScope

local TableUtils = require(Utils.tableUtils)
local TableExtract = TableUtils.Extract

local Components = script.Parent
local Scrollable = require(Components.scrollable)
local Map = require(Components.map)

local Virtualization = require(Components.map.virtualization)
local ComputeMapRowCount, CreateMapSizeTween =
    Virtualization.ComputeMapRowCount,
    Virtualization.CreateMapSizeTween

type MapProps = Map.MapProps

type LayoutOrdered = {
    LayoutOrder: number?
}

type VirtualMapScrollableProps = {
    Maps: Fusion.UsedAs<{ MapProps }>,
    Overdraw: Fusion.UsedAs<number>?,
    Padding: Fusion.UsedAs<number>?
}

local DefaultPadding = 4
local DefaultOverdraw = 200

local function GetLayoutOrder(mapProps: MapProps): number
    -- Component props also carry Roblox instance properties, but MapProps only
    -- describes Map's named API. Narrow that extra property at this boundary.
    local layoutOrdered = (mapProps :: unknown) :: LayoutOrdered
    return layoutOrdered.LayoutOrder or 0
end

local function SortMapProps(mapProps: { MapProps }): { MapProps }
    local sortedMapProps = table.clone(mapProps)

    table.sort(sortedMapProps, function(a: MapProps, b: MapProps): boolean
        return GetLayoutOrder(a) < GetLayoutOrder(b)
    end)

    return sortedMapProps
end

return Component<<VirtualMapScrollableProps>>(function(scope, props)
    local theme = Peek<<ThemeUtils.Theme>>(GetThemeForScope(scope))
    local lgHeight = theme:GetHeight("Lg")

    local props, mapsProps = TableExtract(props, "Maps")
    local props, overdraw = TableExtract(props, "Overdraw")
    local props, padding = TableExtract(props, "Padding", DefaultPadding)

    local viewportAbsolutePositionState =
        Fusion.Value<<Vector2>>(scope, Vector2.new(0, 0))
    local viewportAbsoluteSizeState =
        Fusion.Value<<Vector2>>(scope, Vector2.new(0, 0))
    local viewportCanvasPositionState =
        Fusion.Value<<Vector2>>(scope, Vector2.new(0, 0))
    local canvasHeightState = Fusion.Value<<number>>(scope, 0)

    local overdrawState: Fusion.UsedAs<number> = overdraw or DefaultOverdraw
    local paddingState: Fusion.UsedAs<number> = padding

    local computeSortedMapsProps: Fusion.Computed<{ MapProps }> = Computed(
        scope,
        function(use: Fusion.Use): { MapProps }
            return SortMapProps(use<<{ MapProps }>>(mapsProps :: any))
        end
    )

    local computeCanvasSize = Computed(scope, function(use): UDim2
        return UDim2.fromOffset(0, use<<number>>(canvasHeightState))
    end)

    local computeMapInstances = Computed(scope, function(
        use: Fusion.Use,
        scope: Fusion.Scope
    ): { Fusion.Child }
        local usedMapsProps = use<<{ MapProps }>>(computeSortedMapsProps)
        local mapChildren = table.create(#usedMapsProps) :: { Fusion.Child }

        -- Layout records live in this persistent scope, rather than inside the
        -- mounted Map scopes. An off-screen map can therefore keep animating
        -- its height and continue positioning every map below it.
        local previousBottom: Fusion.UsedAs<number>? = nil

        for idx, mapProps in usedMapsProps do
            local items = mapProps.Items
            local header = mapProps.Header
            local emptyText = mapProps.EmptyText
            local width = mapProps.Width or UDim.new(1, 0)
            local collapsedState = CoerceToValue<<boolean>>(
                scope, mapProps.Collapsed or false
            )

            local rowCount = ComputeMapRowCount(
                scope,
                header,
                items,
                emptyText
            )

            local animatedMapSize = CreateMapSizeTween(
                scope,
                width,
                collapsedState,
                rowCount,
                lgHeight
            )

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

            local mapBottom = Computed(scope, function(use): number
                local usedMapSize = use<<UDim2>>(animatedMapSize)

                return use<<number>>(mapTop) + usedMapSize.Height.Offset
            end)

            local mapOccluded = Computed(scope, function(use): boolean
                local usedViewportSize =
                    use<<Vector2>>(viewportAbsoluteSizeState)

                -- There is no trustworthy viewport on the first evaluation.
                -- Keep maps unmounted until the ScrollingFrame reports one.
                if usedViewportSize.X <= 0 or usedViewportSize.Y <= 0 then
                    return true
                end

                local usedCanvasPosition =
                    use<<Vector2>>(viewportCanvasPositionState)
                local usedOverdraw =
                    math.max(use<<number>>(overdrawState), 0)
                local usedMapTop = use<<number>>(mapTop)
                local usedMapBottom = use<<number>>(mapBottom)

                local viewportTop = usedCanvasPosition.Y - usedOverdraw
                local viewportBottom = usedCanvasPosition.Y
                    + usedViewportSize.Y
                    + usedOverdraw

                -- Partially intersecting maps remain mounted. Only maps whose
                -- complete bounds are outside the overdraw window are culled.
                return usedMapBottom <= viewportTop
                    or usedMapTop >= viewportBottom
            end)

            mapChildren[idx] = Computed(scope, function(
                use,
                mapScope: Fusion.Scope
            ): Fusion.Child
                if use<<boolean>>(mapOccluded) then return {} end

                local geometryReadyState =
                    Fusion.Value<<boolean>>(mapScope, false)
                local mapAbsolutePositionState =
                    Fusion.Value<<Vector2>>(mapScope, Vector2.new(0, 0))
                local mapAbsoluteSizeState =
                    Fusion.Value<<Vector2>>(mapScope, Vector2.new(0, 0))

                local mapInstance = Map(mapScope, mapProps, {
                    Position = mapPosition,
                    AnchorPoint = Vector2.new(0, 0),
                    Collapsed = collapsedState,

                    [Fusion.Out "AbsolutePosition"] =
                        mapAbsolutePositionState,
                    [Fusion.Out "AbsoluteSize"] = mapAbsoluteSizeState,

                    VirtualListData = {
                        AnimatedMapSize = animatedMapSize,
                        RowCount = rowCount,
                        GeometryReady = geometryReadyState,
                        ViewportAbsolutePosition =
                            viewportAbsolutePositionState,
                        ViewportAbsoluteSize = viewportAbsoluteSizeState,
                        MapAbsolutePosition = mapAbsolutePositionState,
                        MapAbsoluteSize = mapAbsoluteSizeState,
                        Overdraw = overdrawState
                    }
                }) :: GuiObject

                local function commitGeometry()
                    if Peek<<boolean>>(geometryReadyState) then return end

                    local viewportAbsoluteSize =
                        Peek<<Vector2>>(viewportAbsoluteSizeState)

                    if viewportAbsoluteSize.X <= 0
                        or viewportAbsoluteSize.Y <= 0
                        or mapInstance.Parent == nil
                        or mapInstance:FindFirstAncestorWhichIsA(
                            "LayerCollector"
                        ) == nil
                    then
                        return
                    end

                    -- Out keeps these values current after this initial pass.
                    -- Opening the gate here prevents rows from evaluating
                    -- against the root's pre-parent zero rectangle.
                    mapAbsolutePositionState:set(mapInstance.AbsolutePosition)
                    mapAbsoluteSizeState:set(mapInstance.AbsoluteSize)
                    geometryReadyState:set(true)
                end

                table.insert(
                    mapScope,
                    mapInstance:GetPropertyChangedSignal("Parent"):Connect(
                        commitGeometry
                    )
                )

                Observer(mapScope, viewportAbsoluteSizeState)
                    :onChange(commitGeometry)
                Observer(mapScope, viewportAbsolutePositionState)
                    :onChange(commitGeometry)

                return mapInstance
            end)

            previousBottom = mapBottom
        end

        local finalBottom = previousBottom

        if finalBottom then
            -- The last animated bottom drives the canvas even if that map is
            -- unmounted, so the scrollbar and collapse tween remain smooth.
            local function publishCanvasHeight()
                canvasHeightState:set(Peek<<number>>(finalBottom))
            end

            Observer(scope, finalBottom):onChange(publishCanvasHeight)
            publishCanvasHeight()
        else
            canvasHeightState:set(0)
        end

        return mapChildren
    end)

    return Scrollable(scope, {
        CanvasSize = computeCanvasSize,
        AutomaticCanvasSize = Enum.AutomaticSize.None,
        OutAbsolutePosition = viewportAbsolutePositionState,
        OutAbsoluteSize = viewportAbsoluteSizeState,
        OutCanvasPosition = viewportCanvasPositionState,

        [Children] = computeMapInstances
    }, (props :: unknown) :: Scrollable.ScrollableOverrides)
end)
