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
local ComputeMath = FusionUtils.ComputeMath
local ComputeAdd, ComputeMultiply = ComputeMath.Add, ComputeMath.Multiply

local ThemeUtils = require(Utils.themeUtils)
local GetThemeForScope = ThemeUtils.GetThemeForScope

local TableUtils = require(Utils.tableUtils)
local TableExtract = TableUtils.Extract

local Components = script.Parent
local Scrollable = require(Components.scrollable)
local Map = require(Components.map)

local Virtualization = require(Components.map.virtualization)
local CreateMapLayout, CreateMapSizeTween =
    Virtualization.CreateMapLayout,
    Virtualization.CreateMapSizeTween
local VirtualizationMath = require(Components.map.virtualization.math)

local VirtualMapScrollableMath = require(script.math)
local ShouldRefreshVirtualWindow, FindVisibleMapRange =
    VirtualMapScrollableMath.ShouldRefreshVirtualWindow,
    VirtualMapScrollableMath.FindVisibleMapRange

type MapProps = Map.MapProps
type MapLayout = Virtualization.MapLayout

type LayoutOrdered = {
    LayoutOrder: number?
}

type MapRecord = {
    Top: Fusion.UsedAs<number>,
    Bottom: Fusion.UsedAs<number>,
    Layout: MapLayout,
    ShowOnTop: Fusion.UsedAs<boolean>,
    Occluded: Fusion.Value<boolean>,
    VisibleRootRange: Fusion.Value<Vector2>
}

type MapIndexSet = { [number]: boolean }

type VirtualMapScrollableProps = {
    Maps: Fusion.UsedAs<{ MapProps }>,
    Overdraw: Fusion.UsedAs<number>?,
    Padding: Fusion.UsedAs<number>?
}

local DefaultPadding = 4
local DefaultOverdrawRows = 6
local VirtualizationStepRows = 1
local BottomPadding = 2

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

    local paddingState: Fusion.UsedAs<number> = padding

    local computeSortedMapsProps: Fusion.Computed<{ MapProps }> = Computed(
        scope,
        function(use: Fusion.Use): { MapProps }
            return SortMapProps(use<<{ MapProps }>>(mapsProps :: any))
        end
    )

    local computeCanvasSize = Computed(scope, function(use: Fusion.Use): UDim2
        return UDim2.fromOffset(0, use<<number>>(canvasHeightState))
    end)

    local theme = GetThemeForScope(scope)
    local height = theme:GetHeight(scope, "Lg")
    local rowHeight = ComputeAdd(scope, height, - 2)
    local defaultOverdraw = ComputeMultiply(
        scope,
        rowHeight,
        DefaultOverdrawRows
    )
    local overdrawState: Fusion.UsedAs<number> =
        overdraw or defaultOverdraw

    local computeMapInstances = Computed(scope, function(
        use: Fusion.Use,
        scope: Fusion.Scope
    ): { Fusion.Child }
        local usedMapsProps = use<<{ MapProps }>>(computeSortedMapsProps)
        local mapChildren = table.create(#usedMapsProps) :: { Fusion.Child }
        local mapRecords = table.create(#usedMapsProps) :: { MapRecord }

        -- Layout records live in this persistent scope, rather than inside the
        -- mounted Map scopes. An off-screen map can therefore keep animating
        -- its height and continue positioning every map below it.
        local previousBottom: Fusion.UsedAs<number>? = nil
        local lastRowFocused: Fusion.UsedAs<boolean>? = nil
        local lastMapCollapsed: Fusion.UsedAs<boolean>? = nil

        for idx, mapProps in usedMapsProps do
            local items = mapProps.Items
            local header = mapProps.Header
            local emptyText = mapProps.EmptyText
            local width = mapProps.Width or UDim.new(1, 0)
            local showOnTop = mapProps.ShowOnTop or false
            local collapsedState = CoerceToValue<<boolean>>(
                scope, mapProps.Collapsed or false
            )

            local layout = CreateMapLayout(
                scope,
                header,
                items,
                emptyText,
                rowHeight
            )
            local animatedMapSize, mapReveal = CreateMapSizeTween(
                scope,
                width,
                collapsedState,
                layout.AnimatedExpandedHeight,
                height
            )

            local mapTop: Fusion.UsedAs<number> = 0

            if previousBottom then
                local priorBottom = previousBottom

                mapTop = Computed(scope, function(use: Fusion.Use): number
                    local usedPadding =
                        math.max(use<<number>>(paddingState), 0)

                    return use<<number>>(priorBottom) + usedPadding
                end)
            end

            local mapPosition = Computed(scope, function(use: Fusion.Use): UDim2
                return UDim2.fromOffset(0, use<<number>>(mapTop))
            end)

            local mapBottom = Computed(scope, function(use: Fusion.Use): number
                local usedMapSize = use<<UDim2>>(animatedMapSize)

                return use<<number>>(mapTop) + usedMapSize.Height.Offset
            end)

            local mapOccludedState =
                Fusion.Value<<boolean>>(scope, true)
            local visibleRootRangeState =
                Fusion.Value<<Vector2>>(scope, Vector2.new(1, 0))

            mapRecords[idx] = {
                Top = mapTop,
                Bottom = mapBottom,
                Layout = layout,
                ShowOnTop = showOnTop,
                Occluded = mapOccludedState,
                VisibleRootRange = visibleRootRangeState
            }

            mapChildren[idx] = Computed(scope, function(
                use: Fusion.Use,
                mapScope: Fusion.Scope
            ): Fusion.Child
                if use<<boolean>>(mapOccludedState) then return {} end

                local geometryReadyState =
                    Fusion.Value<<boolean>>(mapScope, false)
                local mapAbsolutePositionState =
                    Fusion.Value<<Vector2>>(mapScope, Vector2.new(0, 0))
                local mapAbsoluteSizeState =
                    Fusion.Value<<Vector2>>(mapScope, Vector2.new(0, 0))

                -- Component overrides include Fusion special keys and values
                -- created in a different inner scope. Keep that polymorphism
                -- isolated at the component boundary.
                local mapOverrides: any = {
                    Position = mapPosition,
                    AnchorPoint = Vector2.new(0, 0),
                    Collapsed = collapsedState,

                    [Fusion.Out "AbsolutePosition"] =
                        mapAbsolutePositionState,
                    [Fusion.Out "AbsoluteSize"] = mapAbsoluteSizeState,

                    VirtualListData = {
                        Layout = layout,
                        AnimatedMapSize = animatedMapSize,
                        MapReveal = mapReveal,
                        GeometryReady = geometryReadyState,
                        VisibleRootRange = visibleRootRangeState
                    }
                }

                local mapInstance = Map(
                    mapScope,
                    mapProps,
                    mapOverrides
                ) :: GuiObject

                local function commitGeometry()
                    if Peek<<boolean>>(geometryReadyState) then return end

                    local viewportAbsoluteSize =
                        Peek<<Vector2>>(viewportAbsoluteSizeState)
                    local mapAbsoluteSize =
                        Peek<<Vector2>>(mapAbsoluteSizeState)

                    if viewportAbsoluteSize.X <= 0
                        or viewportAbsoluteSize.Y <= 0
                        or mapAbsoluteSize.Y <= 0
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
                Observer(mapScope, mapAbsoluteSizeState)
                    :onChange(commitGeometry)

                return mapInstance
            end)

            previousBottom = mapBottom
            lastRowFocused = layout.LastRowFocused
            lastMapCollapsed = collapsedState
        end

        local emptyRootRange = Vector2.new(1, 0)
        local activeMapIndices = {} :: MapIndexSet
        local retainedMapIndices = {} :: MapIndexSet
        local lastVirtualizationY: number? = nil

        local function getMapTop(mapIdx: number): number
            return Peek<<number>>(mapRecords[mapIdx].Top)
        end

        local function getMapBottom(mapIdx: number): number
            return Peek<<number>>(mapRecords[mapIdx].Bottom)
        end

        local function setOccluded(record: MapRecord, occluded: boolean)
            if Peek<<boolean>>(record.Occluded) == occluded then return end
            record.Occluded:set(occluded)
        end

        local function setVisibleRootRange(
            record: MapRecord,
            visibleRootRange: Vector2
        )
            if Peek<<Vector2>>(record.VisibleRootRange)
                == visibleRootRange
            then
                return
            end

            record.VisibleRootRange:set(visibleRootRange)
        end

        -- Scroll changes enter through this single imperative boundary. A
        -- refresh locates intersecting maps once, then only publishes discrete
        -- row ranges whose values actually changed.
        local function refreshVirtualWindow(force: boolean?)
            local currentCanvasY =
                Peek<<Vector2>>(viewportCanvasPositionState).Y
            local usedOverdraw =
                math.max(Peek<<number>>(overdrawState), 0)
            local usedRowHeight =
                math.max(Peek<<number>>(rowHeight), 0)
            local threshold = math.min(
                usedOverdraw / 2,
                usedRowHeight * VirtualizationStepRows
            )

            if not force
                and not ShouldRefreshVirtualWindow(
                    lastVirtualizationY,
                    currentCanvasY,
                    threshold
                )
            then
                return
            end

            lastVirtualizationY = currentCanvasY

            if force then
                table.clear(retainedMapIndices)

                for mapIdx, record in mapRecords do
                    local focusedRootRange = Peek<<Vector2>>(
                        record.Layout.FocusedRootRange
                    )
                    local hasFocusedRow =
                        focusedRootRange.X <= focusedRootRange.Y

                    if Peek<<boolean>>(record.ShowOnTop)
                        or hasFocusedRow
                    then
                        retainedMapIndices[mapIdx] = true
                    end
                end
            end

            local viewportSize =
                Peek<<Vector2>>(viewportAbsoluteSizeState)
            local viewportReady =
                viewportSize.X > 0 and viewportSize.Y > 0
            local viewportTop = currentCanvasY - usedOverdraw
            local viewportBottom = currentCanvasY
                + viewportSize.Y
                + usedOverdraw
            local firstVisibleMap, lastVisibleMap = 1, 0

            if viewportReady then
                firstVisibleMap, lastVisibleMap = FindVisibleMapRange(
                    #mapRecords,
                    getMapTop,
                    getMapBottom,
                    viewportTop,
                    viewportBottom
                )
            end

            local nextActiveMapIndices = {} :: MapIndexSet

            for mapIdx = firstVisibleMap, lastVisibleMap do
                nextActiveMapIndices[mapIdx] = true
            end

            for mapIdx in retainedMapIndices do
                nextActiveMapIndices[mapIdx] = true
            end

            for mapIdx in activeMapIndices do
                if nextActiveMapIndices[mapIdx] then continue end
                setOccluded(mapRecords[mapIdx], true)
            end

            for mapIdx in nextActiveMapIndices do
                local record = mapRecords[mapIdx]
                local visibleRootRange = emptyRootRange

                if mapIdx >= firstVisibleMap
                    and mapIdx <= lastVisibleMap
                then
                    local mapTop = getMapTop(mapIdx)
                    local rootGeometry = Peek(record.Layout.RootGeometry)
                    local firstRow, lastRow =
                        VirtualizationMath.FindVisibleRange(
                            rootGeometry,
                            viewportTop - mapTop,
                            viewportBottom - mapTop
                        )

                    visibleRootRange = Vector2.new(firstRow, lastRow)
                end

                -- Publish the range before mounting a newly visible map so its
                -- geometry gate opens onto the correct rows.
                setVisibleRootRange(record, visibleRootRange)
                setOccluded(record, false)
            end

            activeMapIndices = nextActiveMapIndices
        end

        -- Geometry and retention changes are correctness invalidations rather
        -- than scroll traffic, so they bypass the movement threshold.
        local computeVirtualizationInputs = Computed(
            scope,
            function(use: Fusion.Use): {}
                use<<Vector2>>(viewportAbsoluteSizeState)
                use<<number>>(overdrawState)
                use<<number>>(rowHeight)

                for _, record in mapRecords do
                    use<<number>>(record.Top)
                    use<<number>>(record.Bottom)
                    use(record.Layout.RootGeometry)
                    use<<Vector2>>(record.Layout.FocusedRootRange)
                    use<<boolean>>(record.ShowOnTop)
                end

                return {}
            end
        )

        Observer(scope, computeVirtualizationInputs):onBind(function()
            refreshVirtualWindow(true)
        end)
        Observer(scope, viewportCanvasPositionState):onChange(function()
            refreshVirtualWindow()
        end)

        local finalBottom = previousBottom
        local finalLastRowFocused = lastRowFocused
        local finalMapCollapsed = lastMapCollapsed

        if finalBottom and finalLastRowFocused and finalMapCollapsed then
            -- The last animated bottom drives the canvas even if that map is
            -- unmounted, so the scrollbar and collapse tween remain smooth.
            local finalRowFocused = Computed(
                scope,
                function(use: Fusion.Use): boolean
                    return
                        not use<<boolean>>(finalMapCollapsed)
                        and use<<boolean>>(finalLastRowFocused)
                end
            )

            local function publishCanvasHeight()
                local bottomPadding =
                    if Peek<<boolean>>(finalRowFocused)
                    then BottomPadding
                    else 0

                canvasHeightState:set(
                    Peek<<number>>(finalBottom) + bottomPadding
                )
            end

            Observer(scope, finalBottom):onChange(publishCanvasHeight)
            Observer(scope, finalRowFocused):onChange(publishCanvasHeight)
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
        PaddingLeft = UDim.new(0, 4),

        [Children] = computeMapInstances
    }, (props :: any))
end)
