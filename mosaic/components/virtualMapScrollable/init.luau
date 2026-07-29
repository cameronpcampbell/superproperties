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
local CreateMapLayout, CreateLazyMapLayout, CreateMapSizeTween =
    Virtualization.CreateMapLayout,
    Virtualization.CreateLazyMapLayout,
    Virtualization.CreateMapSizeTween
local VirtualizationMath = require(Components.map.virtualization.math)

local VirtualMapScrollableMath = require(script.math)
local ShouldRefreshBufferedWindow =
    VirtualMapScrollableMath.ShouldRefreshBufferedWindow
local GetStableLayoutOrderIndices =
    VirtualMapScrollableMath.GetStableLayoutOrderIndices
local FindVisibleMapRange =
    VirtualMapScrollableMath.FindVisibleMapRange

type MapProps = Map.MapProps
type MapLayout = Virtualization.MapLayout
type LazyMapLayout = Virtualization.LazyMapLayout
type RowGeometry = VirtualizationMath.RowGeometry

type LayoutOrdered = {
    LayoutOrder: number?
}

type MapRecord = {
    Top: Fusion.UsedAs<number>,
    Bottom: Fusion.UsedAs<number>,
    Layout: MapLayout,
    ShowOnTop: Fusion.UsedAs<boolean>,
    Occluded: Fusion.Value<boolean>,
    VisibleRootRange: Fusion.Value<Vector2>,
    LoadRootRange: ((
        firstRootRow: number,
        lastRootRow: number
    ) -> ())?
}

export type MapShape = {
    RowCount: number,
    Variant: ThemeUtils.BgVariantLayer?,
    Width: UDim?,
    Header: string?,
    PreviousHeader: string?,
    HeaderColorTint: Fusion.UsedAs<boolean>?,
    HeaderChildren: Map.HeaderChildren?,
    HeaderOverlay: Fusion.Child?,
    ShowOnTop: Fusion.UsedAs<boolean>?,
    EmptyText: string?,
    Collapsible: boolean?,
    Collapsed: Fusion.UsedAs<boolean>?,
    LayoutOrder: number?
}

export type Detail = (
    scope: Fusion.Scope,
    mapIdx: number,
    rowIdx: number
) -> Map.Item

type MapSource = {
    Props: MapProps,
    SourceMapIdx: number,
    RootRowCount: number?
}

type MapIndexSet = { [number]: boolean }

type VirtualWindowRefreshOptions = {
    BypassBuffer: boolean?,
    RebuildRetention: boolean?
}

type VirtualMapScrollableProps = {
    Maps: Fusion.UsedAs<{ MapProps }>?,
    Shape: Fusion.UsedAs<{ MapShape }>?,
    Detail: Detail?,
    Overdraw: Fusion.UsedAs<number>?,
    Padding: Fusion.UsedAs<number>?
}

type VirtualMapScrollableComponent = (
    Fusion.Scope,
    VirtualMapScrollableProps,
    ...any
) -> Fusion.Child

local DefaultPadding = 4
local DefaultOverdrawRows = 6
local MinimumBufferRows = 2
local BottomPadding = 2

local function GetLayoutOrder(mapProps: MapProps): number
    -- Component props also carry Roblox instance properties, but MapProps only
    -- describes Map's named API. Narrow that extra property at this boundary.
    local layoutOrdered = (mapProps :: unknown) :: LayoutOrdered
    return layoutOrdered.LayoutOrder or 0
end

local function SortMapSources(mapSources: { MapSource }): { MapSource }
    local layoutOrders = table.create(#mapSources) :: { number }

    for sourceIndex, source in mapSources do
        layoutOrders[sourceIndex] = GetLayoutOrder(source.Props)
    end

    local sortedSourceIndices =
        GetStableLayoutOrderIndices(layoutOrders)
    local sortedMapSources =
        table.create(#mapSources) :: { MapSource }
    for sortedIndex, sourceIndex in sortedSourceIndices do
        sortedMapSources[sortedIndex] = mapSources[sourceIndex]
    end

    return sortedMapSources
end

local function CreateLegacyMapSources(
    mapPropsList: { MapProps }
): { MapSource }
    local mapSources = table.create(#mapPropsList) :: { MapSource }

    for sourceMapIdx, mapProps in mapPropsList do
        mapSources[sourceMapIdx] = {
            Props = mapProps,
            SourceMapIdx = sourceMapIdx,
            RootRowCount = nil
        }
    end

    return mapSources
end

local function CreateLazyMapSources(
    shape: { MapShape }
): { MapSource }
    local mapSources = table.create(#shape) :: { MapSource }

    for sourceMapIdx, mapShape in shape do
        local rowCount = mapShape.RowCount

        assert(
            type(rowCount) == "number"
                and rowCount >= 0
                and rowCount % 1 == 0,
            `Shape map {sourceMapIdx} RowCount must be a non-negative integer.`
        )

        local mapProps: any = table.clone(mapShape :: any)
        mapProps.RowCount = nil

        assert(
            mapProps.Items == nil
                and mapProps.VirtualListData == nil,
            `Shape map {sourceMapIdx} cannot supply Items or VirtualListData.`
        )

        mapSources[sourceMapIdx] = {
            Props = mapProps :: MapProps,
            SourceMapIdx = sourceMapIdx,
            RootRowCount = rowCount
        }
    end

    return mapSources
end

local VirtualMapScrollableComponent = (Component :: any)(function(
    scope: Fusion.Scope,
    props: any
): Fusion.Child
    local props, mapsProps = (TableExtract :: any)(props, "Maps")
    local props, shape = (TableExtract :: any)(props, "Shape")
    local props, detail = (TableExtract :: any)(props, "Detail")
    local props, overdraw = (TableExtract :: any)(props, "Overdraw")
    local props, padding =
        (TableExtract :: any)(props, "Padding", DefaultPadding)

    local hasMaps = mapsProps ~= nil
    local hasShape = shape ~= nil

    assert(
        hasMaps ~= hasShape,
        "VirtualMapScrollable requires either Maps or Shape, but not both."
    )
    assert(
        (hasShape and type(detail) == "function")
            or (hasMaps and detail == nil),
        "VirtualMapScrollable Detail must be supplied with Shape only."
    )

    local viewportAbsoluteSizeState =
        Fusion.Value<<Vector2>>(scope, Vector2.new(0, 0))
    local viewportCanvasPositionState =
        Fusion.Value<<Vector2>>(scope, Vector2.new(0, 0))
    local canvasHeightState = Fusion.Value<<number>>(scope, 0)

    local paddingState: Fusion.UsedAs<number> = padding

    local computeSortedMapSources: Fusion.Computed<{ MapSource }> = Computed(
        scope,
        function(use: Fusion.Use): { MapSource }
            local mapSources =
                if hasMaps
                then CreateLegacyMapSources(
                    use<<{ MapProps }>>(mapsProps :: any)
                )
                else CreateLazyMapSources(
                    use<<{ MapShape }>>(shape :: any)
                )

            return SortMapSources(mapSources)
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
        local usedMapSources =
            use<<{ MapSource }>>(computeSortedMapSources)
        local mapChildren =
            table.create(#usedMapSources) :: { Fusion.Child }
        local mapRecords =
            table.create(#usedMapSources) :: { MapRecord }

        -- Layout records live in this persistent scope, rather than inside the
        -- mounted Map scopes. An off-screen map can therefore keep animating
        -- its height and continue positioning every map below it.
        local previousBottom: Fusion.UsedAs<number>? = nil
        local lastRowFocused: Fusion.UsedAs<boolean>? = nil
        local lastMapCollapsed: Fusion.UsedAs<boolean>? = nil
        local lastHeader: string? = nil

        for idx, mapSource in usedMapSources do
            local mapProps = mapSource.Props
            local items = mapProps.Items
            local header = mapProps.Header
            local previousHeader =
                mapProps.PreviousHeader or lastHeader
            local emptyText = mapProps.EmptyText
            local width = mapProps.Width or UDim.new(1, 0)
            local showOnTop = mapProps.ShowOnTop or false
            local collapsible = mapProps.Collapsible ~= false
            local collapsedState = CoerceToValue<<boolean>>(
                scope,
                if collapsible then mapProps.Collapsed or false else false
            )

            local layout: MapLayout
            local loadRootRange: ((
                firstRootRow: number,
                lastRootRow: number
            ) -> ())? = nil

            if mapSource.RootRowCount ~= nil then
                local detailCallback = detail :: Detail
                local sourceMapIdx = mapSource.SourceMapIdx
                local lazyLayout: LazyMapLayout = CreateLazyMapLayout(
                    scope,
                    header,
                    mapSource.RootRowCount,
                    emptyText,
                    rowHeight,
                    function(
                        detailScope: Fusion.Scope,
                        itemIdx: number
                    ): Map.Item
                        local item: any = detailCallback(
                            detailScope,
                            sourceMapIdx,
                            itemIdx
                        )

                        assert(
                            type(item) == "table"
                                and type(item.Key) == "string",
                            `Detail must return a Map.Item for map `
                                .. `{sourceMapIdx}, row {itemIdx}.`
                        )

                        return item :: Map.Item
                    end
                )

                layout = lazyLayout
                loadRootRange = lazyLayout.LoadRootRange
            else
                layout = CreateMapLayout(
                    scope,
                    header,
                    items,
                    emptyText,
                    rowHeight
                )
            end

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
                VisibleRootRange = visibleRootRangeState,
                LoadRootRange = loadRootRange
            }

            mapChildren[idx] = Computed(scope, function(
                use: Fusion.Use,
                mapScope: Fusion.Scope
            ): Fusion.Child
                if use<<boolean>>(mapOccludedState) then return {} end

                -- Component overrides include Fusion special keys and values
                -- created in a different inner scope. Keep that polymorphism
                -- isolated at the component boundary.
                local mapOverrides: any = {
                    Position = mapPosition,
                    AnchorPoint = Vector2.new(0, 0),
                    Collapsed = collapsedState,
                    PreviousHeader = previousHeader,

                    VirtualListData = {
                        Layout = layout,
                        AnimatedMapSize = animatedMapSize,
                        MapReveal = mapReveal,
                        -- The parent publishes a numeric range before mounting
                        -- the Map, so no engine rectangle is needed here.
                        GeometryReady = true,
                        VisibleRootRange = visibleRootRangeState
                    }
                }

                return Map(
                    mapScope,
                    mapProps,
                    mapOverrides
                )
            end)

            previousBottom = mapBottom
            lastRowFocused = layout.LastRowFocused
            lastMapCollapsed = collapsedState
            lastHeader = header or lastHeader
        end

        local emptyRootRange = Vector2.new(1, 0)
        local activeMapIndices = {} :: MapIndexSet
        local nextActiveMapIndices = {} :: MapIndexSet
        local retainedMapIndices = {} :: MapIndexSet
        local renderedWindowTop: number? = nil
        local renderedWindowBottom: number? = nil
        local refreshInProgress = false
        local refreshPending = false
        local pendingBypassBuffer = false
        local pendingRebuildRetention = false

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

        local function rebuildRetainedMapIndices()
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

        -- Scroll changes enter through this single imperative boundary. A
        -- refresh locates intersecting maps once, then only publishes discrete
        -- row ranges whose values actually changed.
        local function refreshVirtualWindow(
            options: VirtualWindowRefreshOptions?
        )
            local bypassBuffer =
                options ~= nil and options.BypassBuffer == true
            local rebuildRetention =
                options ~= nil and options.RebuildRetention == true

            if refreshInProgress then
                refreshPending = true
                pendingBypassBuffer =
                    pendingBypassBuffer or bypassBuffer
                pendingRebuildRetention =
                    pendingRebuildRetention or rebuildRetention
                return
            end

            refreshInProgress = true

            local currentCanvasY =
                Peek<<Vector2>>(viewportCanvasPositionState).Y
            local usedOverdraw =
                math.max(Peek<<number>>(overdrawState), 0)
            local usedRowHeight =
                math.max(Peek<<number>>(rowHeight), 0)
            local minimumBuffer = math.min(
                usedOverdraw / 2,
                usedRowHeight * MinimumBufferRows
            )
            local viewportSize =
                Peek<<Vector2>>(viewportAbsoluteSizeState)
            local viewportReady =
                viewportSize.X > 0 and viewportSize.Y > 0
            local viewportTop = currentCanvasY
            local viewportBottom = currentCanvasY + viewportSize.Y

            if rebuildRetention then
                rebuildRetainedMapIndices()
                bypassBuffer = true
            end

            if viewportReady
                and not bypassBuffer
                and not ShouldRefreshBufferedWindow(
                    renderedWindowTop,
                    renderedWindowBottom,
                    viewportTop,
                    viewportBottom,
                    minimumBuffer
                )
            then
                refreshInProgress = false
                return
            end

            if viewportReady then
                renderedWindowTop = viewportTop - usedOverdraw
                renderedWindowBottom = viewportBottom + usedOverdraw
            else
                renderedWindowTop = nil
                renderedWindowBottom = nil
            end

            local queryTop = renderedWindowTop or viewportTop
            local queryBottom = renderedWindowBottom or viewportBottom
            local firstVisibleMap, lastVisibleMap = 1, 0

            if viewportReady then
                firstVisibleMap, lastVisibleMap = FindVisibleMapRange(
                    #mapRecords,
                    getMapTop,
                    getMapBottom,
                    queryTop,
                    queryBottom
                )
            end

            table.clear(nextActiveMapIndices)

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
                    local rootGeometry =
                        Peek<<RowGeometry>>(record.Layout.RootGeometry)
                    local firstRow, lastRow =
                        VirtualizationMath.FindVisibleRange(
                            rootGeometry,
                            queryTop - mapTop,
                            queryBottom - mapTop
                        )

                    if record.LoadRootRange then
                        record.LoadRootRange(firstRow, lastRow)
                    end

                    visibleRootRange = Vector2.new(firstRow, lastRow)
                end

                -- Publish the range before mounting a newly visible map so its
                -- first row reconciliation starts with the correct window.
                setVisibleRootRange(record, visibleRootRange)
                setOccluded(record, false)
            end

            activeMapIndices, nextActiveMapIndices =
                nextActiveMapIndices, activeMapIndices

            refreshInProgress = false

            if refreshPending then
                local nextBypassBuffer = pendingBypassBuffer
                local nextRebuildRetention =
                    pendingRebuildRetention

                refreshPending = false
                pendingBypassBuffer = false
                pendingRebuildRetention = false

                refreshVirtualWindow({
                    BypassBuffer = nextBypassBuffer,
                    RebuildRetention = nextRebuildRetention
                })
            end
        end

        -- Geometry changes are correctness invalidations rather than scroll
        -- traffic, so they bypass buffer hysteresis without rescanning focus
        -- and pinned-map retention.
        local computeGeometryInputs = Computed(
            scope,
            function(use: Fusion.Use): {}
                use<<Vector2>>(viewportAbsoluteSizeState)
                use<<number>>(overdrawState)
                use<<number>>(rowHeight)

                for _, record in mapRecords do
                    use<<number>>(record.Top)
                    use<<number>>(record.Bottom)
                    use<<RowGeometry>>(record.Layout.RootGeometry)
                end

                return {}
            end
        )
        local computeRetentionInputs = Computed(
            scope,
            function(use: Fusion.Use): {}
                for _, record in mapRecords do
                    use<<Vector2>>(record.Layout.FocusedRootRange)
                    use<<boolean>>(record.ShowOnTop)
                end

                return {}
            end
        )

        rebuildRetainedMapIndices()
        Observer(scope, computeGeometryInputs):onBind(function()
            refreshVirtualWindow({
                BypassBuffer = true
            })
        end)
        Observer(scope, computeRetentionInputs):onChange(function()
            refreshVirtualWindow({
                RebuildRetention = true
            })
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
        OutAbsoluteSize = viewportAbsoluteSizeState,
        OutCanvasPosition = viewportCanvasPositionState,
        PaddingLeft = UDim.new(0, 4),

        [Children] = computeMapInstances
    }, (props :: any))
end) :: VirtualMapScrollableComponent

return VirtualMapScrollableComponent
