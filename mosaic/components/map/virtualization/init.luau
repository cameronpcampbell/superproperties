--!strict

local Packages = script.Parent.Parent.Parent.Parent

local Fusion = require(Packages.fusion)
local Children, Computed, New, Observer, Peek, Tween, Value =
    Fusion.Children, Fusion.Computed, Fusion.New, Fusion.Observer,
    Fusion.peek, Fusion.Tween, Fusion.Value

local Utils = script.Parent.Parent.Parent.utils
local ThemeUtils = require(Utils.themeUtils)

local Types = require(script.Parent.types)
local MapTweenInfo = require(script.Parent.animation)
local MapHeader = require(script.Parent.header)
local MapItem = require(script.Parent.item)
local IntrinsicSubItems = require(script.Parent.item.intrinsicSubItems)
local IntrinsicSubItemDefinitions = IntrinsicSubItems.Definitions
local MapEmptyItem = require(script.Parent.emptyItem)
local VirtualizationMath = require(script.math)

local RowGap = 1
local MapContentPadding = 1

type Item = Types.Item
type Items = Types.Items
type TrySet<T> = Types.TrySet<T>
type IntrinsicAccessor = Types.IntrinsicAccessor
type IntrinsicItem = Types.IntrinsicItem
type IntrinsicItems = Types.IntrinsicItems
type ItemDefinition = Item | IntrinsicItem
type ItemLayout = Types.ItemLayout
type RowMetadata = Types.RowMetadata
type RootRowDescriptor = ItemLayout | string
type RootRowDescriptors = { [number]: RootRowDescriptor }
type RootRowGeometry = VirtualizationMath.RowGeometry
type RenderedRows = { [number]: Instance }
type HeaderContentCache = {
    CacheParent: Folder,
    ChildrenFrame: Frame,
    OverlayFrame: Frame
}
type ResolvedItem = {
    Item: ItemDefinition,
    RootItem: Item,
    RootValue: any,
    ResolvedValue: any,
    ValueType: string?,
    ValueAccessor: IntrinsicAccessor?,
    TrySetKey: TrySet<string>?,
    TrySetValue: TrySet<any>?,
    KeyWritable: boolean,
    ValueWritable: boolean,
    DisplayAsWritable: boolean
}
type CollapseStateNode = {
    IsCollapsed: boolean?,
    Children: { [ItemDefinition]: CollapseStateNode }
}

local HeaderRowDescriptor: "Header" = "Header"
local EmptyRowDescriptor: "Empty" = "Empty"

export type MapLayout = {
    RootItems: Fusion.UsedAs<{ ItemLayout }>,
    RootRows: Fusion.UsedAs<RootRowDescriptors>,
    RootGeometry: Fusion.UsedAs<RootRowGeometry>,
    FocusedRootRange: Fusion.UsedAs<Vector2>,
    LastRowFocused: Fusion.UsedAs<boolean>,
    AnimatedExpandedHeight: Fusion.UsedAs<number>,
    Metadata: Fusion.UsedAs<RowMetadata>,
    CornerRowCount: Fusion.UsedAs<number>,
    RowCount: Fusion.UsedAs<number>
}

export type VirtualListData = {
    Layout: MapLayout,
    AnimatedMapSize: Fusion.UsedAs<UDim2>?,
    MapReveal: Fusion.UsedAs<number>?,
    GeometryReady: Fusion.UsedAs<boolean>,
    ViewportCanvasPosition: Fusion.UsedAs<Vector2>,
    ViewportAbsoluteSize: Fusion.UsedAs<Vector2>,
    MapCanvasTop: Fusion.UsedAs<number>,
    Overdraw: Fusion.UsedAs<number>
}

export type VirtualRowsConfig = {
    Variant: ThemeUtils.BgVariantLayer,
    Header: string?,
    HeaderChildren: { Fusion.Child }?,
    HeaderOverlay: Fusion.Child?,
    HeaderZIndex: Fusion.UsedAs<number>,
    ShowOnTop: Fusion.UsedAs<boolean>,
    EmptyText: string?,
    Layout: MapLayout,
    CollapsedState: Fusion.Value<boolean>,
    AnimatedMapSize: Fusion.UsedAs<UDim2>,
    VisibleRootRange: Fusion.UsedAs<Vector2>?,
    RowHeight: Fusion.UsedAs<number>
}

type MountedRow = {
    Scope: Fusion.Scope,
    Descriptor: RootRowDescriptor,
    Instance: Instance
}

local function CalculateMapHeight(rowCount: number, height: number): number
    local rowHeight = height - 2
    return rowHeight * rowCount + rowCount + 1
end

local function CreateHeaderContentCache(
    scope: Fusion.Scope,
    headerChildren: { Fusion.Child }?,
    headerOverlay: Fusion.Child?
): HeaderContentCache
    local cacheParent = New(scope, "Folder") {
        Name = "MapHeaderContentCache"
    } :: Folder
    local childrenFrame = New(scope, "Frame") {
        Parent = cacheParent,
        Size = UDim2.fromScale(0, 1),
        AutomaticSize = Enum.AutomaticSize.X,
        BackgroundTransparency = 1,
        LayoutOrder = 2,

        Name = "HeaderChildren",

        [Children] = ({
            headerChildren or {},

            New(scope, "UIListLayout") {
                Padding = UDim.new(0, 6),
                FillDirection = Enum.FillDirection.Horizontal,
                HorizontalAlignment = Enum.HorizontalAlignment.Right,
                VerticalAlignment = Enum.VerticalAlignment.Center
            }
        } :: { Fusion.Child })
    } :: Frame
    local overlayFrame = New(scope, "Frame") {
        Parent = cacheParent,
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,

        Name = "HeaderOverlay",

        [Children] = headerOverlay or {}
    } :: Frame

    return {
        CacheParent = cacheParent,
        ChildrenFrame = childrenFrame,
        OverlayFrame = overlayFrame
    }
end

local function CreateCollapseRevealTween(
    scope: Fusion.Scope,
    collapsed: Fusion.UsedAs<boolean>
): Fusion.Tween<number>
    return Tween<<number>>(
        scope,
        Computed(scope, function(use: Fusion.Use): number
            return if use<<boolean>>(collapsed) then 0 else 1
        end),
        MapTweenInfo
    )
end

local function GetCollapseStateNode(
    parent: CollapseStateNode,
    item: ItemDefinition
): CollapseStateNode
    local existingNode = parent.Children[item]
    if existingNode then return existingNode end

    local node: CollapseStateNode = {
        IsCollapsed = nil,
        Children = {}
    }
    parent.Children[item] = node

    return node
end

local function CreateCachedCollapsedState(
    scope: Fusion.Scope,
    node: CollapseStateNode
): Fusion.Value<boolean>
    local cachedIsCollapsed = node.IsCollapsed
    local isCollapsed: boolean =
        if cachedIsCollapsed == nil then true else cachedIsCollapsed

    local collapsedState = Value<<boolean>>(scope, isCollapsed)
    node.IsCollapsed = isCollapsed

    Observer(scope, collapsedState):onChange(function()
        node.IsCollapsed = Peek<<boolean>>(collapsedState)
    end)

    return collapsedState
end

local function ResolveItem(item: Item): ResolvedItem
    local trySetKey = item.TrySetKey
    local trySetValue = item.TrySetValue
    local valueType = item.ValueType
    local keyWritable =
        item.KeyWritable ~= false and
        trySetKey ~= nil
    local valueWritable =
        item.ValueWritable ~= false and
        trySetValue ~= nil

    if valueType == nil and item.Value ~= nil then
        valueType = typeof(item.Value)
    end

    return {
        Item = item,
        RootItem = item,
        RootValue = item.Value,
        ResolvedValue = item.Value,
        ValueType = valueType,
        ValueAccessor = nil,
        TrySetKey = if keyWritable then trySetKey else nil,
        TrySetValue = if valueWritable then trySetValue else nil,
        KeyWritable = keyWritable,
        ValueWritable = valueWritable,
        DisplayAsWritable =
            keyWritable or valueWritable or item.DisplayAsWritable == true
    }
end

local function ResolveIntrinsicItem(
    item: IntrinsicItem,
    rootItem: Item,
    rootValue: any,
    parentValueWritable: boolean,
    parentDisplayAsWritable: boolean
): ResolvedItem
    local valueAccessor = item.Value
    local writeValue = valueAccessor.Write
    local resolvedValue = valueAccessor.Read(rootValue)
    local trySetRootValue = rootItem.TrySetValue
    local trySetValue: TrySet<any>? = nil

    if parentValueWritable and trySetRootValue then
        trySetValue = function(value: any): (boolean, string?, any?)
            local nextRootValue = writeValue(
                rootItem.Value,
                value
            )

            local success, err, savedRootValue =
                trySetRootValue(nextRootValue)

            if not success or savedRootValue == nil then
                return success, err, nil
            end

            return true, nil, valueAccessor.Read(savedRootValue)
        end
    end

    return {
        Item = item,
        RootItem = rootItem,
        RootValue = rootValue,
        ResolvedValue = resolvedValue,
        ValueType = typeof(resolvedValue),
        ValueAccessor = valueAccessor,
        TrySetKey = nil,
        TrySetValue = trySetValue,
        KeyWritable = false,
        ValueWritable = parentValueWritable,
        DisplayAsWritable = parentDisplayAsWritable
    }
end

local function GetChildItems(item: ResolvedItem): { ResolvedItem }
    if item.ValueAccessor then
        local intrinsicParent = item.Item :: IntrinsicItem
        local intrinsicItems: IntrinsicItems =
            intrinsicParent.SubItems or {}
        local childItems = table.create(#intrinsicItems) :: { ResolvedItem }

        for childIdx, childItem in intrinsicItems do
            childItems[childIdx] = ResolveIntrinsicItem(
                childItem,
                item.RootItem,
                item.RootValue,
                item.ValueWritable,
                item.DisplayAsWritable
            )
        end

        return childItems
    end

    local intrinsicItems: IntrinsicItems =
        IntrinsicSubItemDefinitions[typeof(item.ResolvedValue)] or {}
    local suppliedParent = item.Item :: Item
    local suppliedMapItems: Items = suppliedParent.SubItems or {}
    local childItems = table.create(
        #intrinsicItems + #suppliedMapItems
    ) :: { ResolvedItem }

    for childIdx, childItem in intrinsicItems do
        childItems[childIdx] = ResolveIntrinsicItem(
            childItem,
            item.RootItem,
            item.RootValue,
            item.ValueWritable,
            item.DisplayAsWritable
        )
    end

    for childIdx, childItem in suppliedMapItems do
        childItems[#intrinsicItems + childIdx] = ResolveItem(childItem)
    end

    return childItems
end

local function CreateItemLayout(
    scope: Fusion.Scope,
    collapseStateNode: CollapseStateNode,
    resolvedItem: ResolvedItem,
    depth: number,
    rowHeight: number,
    canBecomeMapBottom: boolean
): ItemLayout
    local item = resolvedItem.Item
    local childItems = GetChildItems(resolvedItem)
    local children = table.create(#childItems) :: { ItemLayout }

    for childIdx, childItem in childItems do
        local childCollapseStateNode = GetCollapseStateNode(
            collapseStateNode,
            childItem.Item
        )

        children[childIdx] = CreateItemLayout(
            scope,
            childCollapseStateNode,
            childItem,
            depth + 1,
            rowHeight,
            canBecomeMapBottom and childIdx == #childItems
        )
    end

    local childrenContentHeight = Computed(scope, function(use: Fusion.Use): number
        local height = 0

        for childIdx, child in children do
            if childIdx > 1 then height += RowGap end
            height += use<<number>>(child.AnimatedHeight)
        end

        return height
    end)

    local collapsedState: Fusion.Value<boolean>? = nil
    if #children > 0 then
        collapsedState = item.Collapsed
            or CreateCachedCollapsedState(scope, collapseStateNode)
    end

    local childrenMounted: Fusion.UsedAs<boolean> = false

    if collapsedState then
        local childrenMountedState = Value<<boolean>>(
            scope,
            not Peek<<boolean>>(collapsedState)
        )
        childrenMounted = childrenMountedState

        local function retainExpandedChildren()
            if Peek<<boolean>>(childrenMountedState) then return end
            if Peek<<boolean>>(collapsedState :: Fusion.Value<boolean>) then
                return
            end

            -- GUI descendants are expensive to recreate and carry focus/input
            -- state. Once a branch is opened, retain it until its root row is
            -- culled rather than rebuilding it on every collapse toggle.
            childrenMountedState:set(true)
        end

        Observer(scope, collapsedState):onChange(retainExpandedChildren)
    end

    local reveal = if collapsedState
        then CreateCollapseRevealTween(scope, collapsedState)
        else nil

    local animatedChildrenHeight = Computed(scope, function(use: Fusion.Use): number
        if not reveal then return 0 end

        return use<<number>>(reveal)
            * (RowGap + use<<number>>(childrenContentHeight))
    end)

    local cornersCollapsed: Fusion.Computed<boolean>? = nil
    if reveal then
        local animatedReveal = reveal
        cornersCollapsed = Computed(scope, function(use: Fusion.Use): boolean
            return use<<number>>(animatedReveal) == 0
        end)
    end

    local animatedHeight = Computed(scope, function(use: Fusion.Use): number
        return rowHeight + use<<number>>(animatedChildrenHeight)
    end)
    local keyFocusState = Value<<boolean>>(scope, false)
    local keyFocusElevationState = Value<<boolean>>(scope, false)
    local valueFocusState = Value<<boolean>>(scope, false)
    local valueFocusElevationState = Value<<boolean>>(scope, false)

    return {
        Item = item,
        ResolvedValue = resolvedItem.ResolvedValue,
        ValueType = resolvedItem.ValueType,
        TrySetKey = resolvedItem.TrySetKey,
        TrySetValue = resolvedItem.TrySetValue,
        KeyWritable = resolvedItem.KeyWritable,
        ValueWritable = resolvedItem.ValueWritable,
        DisplayAsWritable = resolvedItem.DisplayAsWritable,
        KeyFocusState = keyFocusState,
        KeyFocusElevationState = keyFocusElevationState,
        ValueFocusState = valueFocusState,
        ValueFocusElevationState = valueFocusElevationState,
        Depth = depth,
        CanBecomeMapBottom = canBecomeMapBottom,
        CollapsedState = collapsedState,
        ChildrenMounted = childrenMounted,
        ChildrenReveal = reveal,
        CornersCollapsed = cornersCollapsed,
        Children = children,
        ChildrenContentHeight = childrenContentHeight,
        AnimatedChildrenHeight = animatedChildrenHeight,
        AnimatedHeight = animatedHeight
    }
end

local function UseItemTreeFocus(
    use: Fusion.Use,
    layout: ItemLayout
): boolean
    if use<<boolean>>(layout.KeyFocusState) then return true end
    if use<<boolean>>(layout.KeyFocusElevationState) then return true end
    if use<<boolean>>(layout.ValueFocusState) then return true end
    if use<<boolean>>(layout.ValueFocusElevationState) then return true end

    for _, child in layout.Children do
        if UseItemTreeFocus(use, child) then return true end
    end

    return false
end

local function ComputeRowMetadata(
    scope: Fusion.Scope,
    rootItems: Fusion.Computed<{ ItemLayout }>,
    header: string?,
    emptyText: string?,
    useAnimatedCollapse: boolean
): Fusion.Computed<RowMetadata>
    return Computed(scope, function(use: Fusion.Use): RowMetadata
        local usedRootItems = use<<{ ItemLayout }>>(rootItems)
        local rowIndices = {} :: { [ItemLayout]: number }
        local rowCount = if header then 1 else 0

        local function visit(layout: ItemLayout)
            rowCount += 1
            rowIndices[layout] = rowCount

            local collapsedState =
                if useAnimatedCollapse then layout.CornersCollapsed
                else layout.CollapsedState

            if collapsedState and use<<boolean>>(collapsedState) then return end

            for _, child in layout.Children do visit(child) end
        end

        if #usedRootItems > 0 then
            for _, layout in usedRootItems do visit(layout) end
        elseif emptyText then
            rowCount += 1
        end

        return {
            RowCount = rowCount,
            RowIndices = rowIndices
        }
    end)
end

local function UseRootRowHeight(
    use: Fusion.Use,
    descriptor: RootRowDescriptor,
    rowHeight: number
): number
    if descriptor == HeaderRowDescriptor
        or descriptor == EmptyRowDescriptor
    then
        return rowHeight
    end

    return use<<number>>((descriptor :: ItemLayout).AnimatedHeight)
end

local function CreateMapLayout(
    scope: Fusion.Scope,
    header: string?,
    items: Fusion.UsedAs<Items>?,
    emptyText: string?,
    rowHeight: Fusion.UsedAs<number>
): MapLayout
    -- Cached booleans outlive recomputed item layouts. The reactive layout
    -- remains in the caller's scope so downstream Computeds can depend on it.
    local mapLayoutScope = scope
    local collapseStateRoot: CollapseStateNode = {
        IsCollapsed = nil,
        Children = {}
    }

    table.insert(mapLayoutScope, function()
        table.clear(collapseStateRoot.Children)
    end)

    local rootItems = Computed(mapLayoutScope, function(
        use: Fusion.Use,
        layoutScope: Fusion.Scope
    ): { ItemLayout }
        local usedItems: Items = if items then use<<Items>>(items) else {}
        local usedRowHeight = use<<number>>(rowHeight)
        local layouts = table.create(#usedItems) :: { ItemLayout }

        for itemIdx, item in usedItems do
            local collapseStateNode = GetCollapseStateNode(
                collapseStateRoot,
                item
            )

            layouts[itemIdx] = CreateItemLayout(
                layoutScope,
                collapseStateNode,
                ResolveItem(item),
                1,
                usedRowHeight,
                itemIdx == #usedItems
            )
        end

        return layouts
    end)

    local rootRows = Computed(
        mapLayoutScope,
        function(use: Fusion.Use): RootRowDescriptors
            local usedRootItems = use<<{ ItemLayout }>>(rootItems)
            local rows = {} :: RootRowDescriptors

            if header then table.insert(rows, HeaderRowDescriptor) end

            if #usedRootItems > 0 then
                for _, layout in usedRootItems do table.insert(rows, layout) end
            elseif emptyText then
                table.insert(rows, EmptyRowDescriptor)
            end

            return rows
        end
    )

    local focusedRootRange = Computed(
        mapLayoutScope,
        function(use: Fusion.Use): Vector2
            local usedRootRows = use<<RootRowDescriptors>>(rootRows)
            local firstRow, lastRow: number? = nil, nil

            for rootIdx, descriptor in usedRootRows do
                if descriptor ~= HeaderRowDescriptor
                    and descriptor ~= EmptyRowDescriptor
                    and UseItemTreeFocus(use, descriptor :: ItemLayout)
                then
                    firstRow = firstRow or rootIdx
                    lastRow = rootIdx
                end
            end

            if not firstRow or not lastRow then
                return Vector2.new(1, 0)
            end

            return Vector2.new(firstRow, lastRow)
        end
    )

    local rootGeometry = Computed(
        mapLayoutScope,
        function(use: Fusion.Use): RootRowGeometry
            local usedRootRows = use<<RootRowDescriptors>>(rootRows)
            local usedRowHeight = use<<number>>(rowHeight)
            local rowHeights = table.create(#usedRootRows) :: { number }

            for rootIdx, descriptor in usedRootRows do
                rowHeights[rootIdx] = UseRootRowHeight(
                    use,
                    descriptor,
                    usedRowHeight
                )
            end

            return VirtualizationMath.BuildRowGeometry(
                rowHeights,
                MapContentPadding,
                RowGap
            )
        end
    )

    local animatedExpandedHeight = Computed(
        mapLayoutScope,
        function(use: Fusion.Use): number
            return use<<RootRowGeometry>>(rootGeometry).TotalHeight
        end
    )

    local targetMetadata = ComputeRowMetadata(
        mapLayoutScope,
        rootItems,
        header,
        emptyText,
        false
    )
    local metadata = ComputeRowMetadata(
        mapLayoutScope,
        rootItems,
        header,
        emptyText,
        true
    )

    local lastRowFocused = Computed(
        mapLayoutScope,
        function(use: Fusion.Use): boolean
            local usedMetadata = use<<RowMetadata>>(metadata)
            local lastRowIdx = usedMetadata.RowCount

            for itemLayout, rowIdx in usedMetadata.RowIndices do
                if rowIdx == lastRowIdx then
                    return
                        use<<boolean>>(itemLayout.KeyFocusState)
                        or use<<boolean>>(itemLayout.ValueFocusState)
                end
            end

            return false
        end
    )

    local rowCount = Computed(mapLayoutScope, function(use: Fusion.Use): number
        return use<<RowMetadata>>(targetMetadata).RowCount
    end)
    local cornerRowCount = Computed(
        mapLayoutScope,
        function(use: Fusion.Use): number
            return use<<RowMetadata>>(metadata).RowCount
        end
    )

    return {
        RootItems = rootItems,
        RootRows = rootRows,
        RootGeometry = rootGeometry,
        FocusedRootRange = focusedRootRange,
        LastRowFocused = lastRowFocused,
        AnimatedExpandedHeight = animatedExpandedHeight,
        Metadata = metadata,
        CornerRowCount = cornerRowCount,
        RowCount = rowCount
    }
end

local function CreateMapSizeTween(
    scope: Fusion.Scope,
    width: UDim,
    collapsed: Fusion.UsedAs<boolean>,
    animatedExpandedHeight: Fusion.UsedAs<number>,
    height: Fusion.UsedAs<number>
): (Fusion.Computed<UDim2>, Fusion.Tween<number>)
    local reveal = CreateCollapseRevealTween(scope, collapsed)

    local size = Computed(scope, function(use: Fusion.Use): UDim2
        local usedHeight = use<<number>>(height)

        local resolvedHeight = usedHeight
            + use<<number>>(reveal)
                * (use<<number>>(animatedExpandedHeight) - usedHeight)

        return UDim2.new(width, UDim.new(0, resolvedHeight))
    end)

    return size, reveal
end

local function IsEmptyRootRange(range: Vector2): boolean
    return range.X > range.Y
end

local function UnionRootRanges(a: Vector2, b: Vector2): Vector2
    if IsEmptyRootRange(a) then return b end
    if IsEmptyRootRange(b) then return a end

    return Vector2.new(
        math.min(a.X, b.X),
        math.max(a.Y, b.Y)
    )
end

local function ComputeVirtualListVisibleRootRange(
    scope: Fusion.Scope,
    virtualListData: VirtualListData?,
    layout: MapLayout
): Fusion.Computed<Vector2>?
    if not virtualListData then return nil end

    return Computed(scope, function(use: Fusion.Use): Vector2
        local focusedRootRange =
            use<<Vector2>>(layout.FocusedRootRange)

        if not use<<boolean>>(virtualListData.GeometryReady) then
            return focusedRootRange
        end

        local rootGeometry =
            use<<RootRowGeometry>>(layout.RootGeometry)
        if #rootGeometry.Tops == 0 then return focusedRootRange end

        local mapCanvasTop = use<<number>>(virtualListData.MapCanvasTop)
        local canvasPosition =
            use<<Vector2>>(virtualListData.ViewportCanvasPosition)
        local viewportSize =
            use<<Vector2>>(virtualListData.ViewportAbsoluteSize)
        local overdraw = math.max(
            use<<number>>(virtualListData.Overdraw),
            0
        )

        local viewportTop = canvasPosition.Y - overdraw - mapCanvasTop
        local viewportBottom = canvasPosition.Y
            + viewportSize.Y
            + overdraw
            - mapCanvasTop
        local firstRow, lastRow = VirtualizationMath.FindVisibleRange(
            rootGeometry,
            viewportTop,
            viewportBottom
        )
        local visibleRootRange = Vector2.new(firstRow, lastRow)

        return UnionRootRanges(visibleRootRange, focusedRootRange)
    end)
end

local function CreateRow(
    scope: Fusion.Scope,
    config: VirtualRowsConfig,
    headerContentCache: HeaderContentCache?,
    rootIdx: number,
    descriptor: RootRowDescriptor
): Instance
    local rowCount = config.Layout.RowCount

    if descriptor == HeaderRowDescriptor then
        local cache = assert(
            headerContentCache,
            "Header rows must have a content cache."
        )

        -- MapHeader's cleanup unparents the frames first. Since scopes clean
        -- up in reverse order, this earlier task returns them to the cache for
        -- the next virtualized header mount.
        table.insert(scope, function()
            cache.ChildrenFrame.Parent = cache.CacheParent
            cache.OverlayFrame.Parent = cache.CacheParent
        end)

        return MapHeader(scope, {
            Header = config.Header :: string,
            HeaderChildrenFrame = cache.ChildrenFrame,
            HeaderOverlayFrame = cache.OverlayFrame,
            ZIndex = config.HeaderZIndex,
            Variant = config.Variant,
            RowCount = rowCount,
            RowIdx = 1,
            CollapsedState = config.CollapsedState,
            TweenComputeMapSize = config.AnimatedMapSize
        })
    end

    if descriptor == EmptyRowDescriptor then
        return MapEmptyItem(scope, {
            Text = config.EmptyText :: string,
            Variant = config.Variant,
            RowCount = rowCount,
            RowIdx = if config.Header then 2 else 1
        })
    end

    return MapItem(scope, {
        Variant = config.Variant,
        Layout = descriptor :: ItemLayout,
        LayoutOrder = rootIdx,
        RowCount = config.Layout.CornerRowCount,
        RowMetadata = config.Layout.Metadata
    })
end

local function ComputeVisibleRootDescriptors(
    scope: Fusion.Scope,
    config: VirtualRowsConfig
): Fusion.Computed<RootRowDescriptors>
    return Computed(scope, function(use: Fusion.Use): RootRowDescriptors
        local rootRows = use<<RootRowDescriptors>>(config.Layout.RootRows)
        local firstRow, lastRow = 1, #rootRows

        if config.VisibleRootRange then
            local visibleRange = use<<Vector2>>(config.VisibleRootRange)
            firstRow, lastRow = visibleRange.X, visibleRange.Y
        end

        local descriptors = {} :: RootRowDescriptors

        if firstRow <= lastRow then
            for rootIdx = firstRow, lastRow do
                local descriptor = rootRows[rootIdx]
                if descriptor then descriptors[rootIdx] = descriptor end
            end
        end

        if config.Header and use<<boolean>>(config.ShowOnTop) then
            local headerDescriptor = rootRows[1]
            if headerDescriptor then descriptors[1] = headerDescriptor end
        end

        return descriptors
    end)
end

local function CreateRenderedRows(
    scope: Fusion.Scope,
    config: VirtualRowsConfig,
    visibleDescriptors: Fusion.Computed<RootRowDescriptors>,
    headerContentCache: HeaderContentCache?
): Fusion.Value<RenderedRows>
    local renderedRows = Fusion.Value<<RenderedRows>>(scope, {})
    local mountedRows = {} :: { [number]: MountedRow }

    local function reconcileRows()
        local descriptors = Peek<<RootRowDescriptors>>(visibleDescriptors)
        local nextMountedRows = {} :: { [number]: MountedRow }
        local nextRenderedRows = {} :: RenderedRows

        for rootIdx, mountedRow in mountedRows do
            local descriptor = descriptors[rootIdx]
            if descriptor and mountedRow.Descriptor == descriptor then
                nextMountedRows[rootIdx] = mountedRow
                nextRenderedRows[rootIdx] = mountedRow.Instance
                continue
            end

            -- Supplied row children can be shared by successive item layouts.
            -- Clean up replaced rows before mounting their replacements so an
            -- old [Children] cleanup cannot unparent them from the new row.
            Fusion.doCleanup(mountedRow.Scope)
        end

        for rootIdx, descriptor in descriptors do
            if nextMountedRows[rootIdx] then continue end

            local rowScope = Fusion.innerScope(scope)
            local rowInstance = CreateRow(
                rowScope,
                config,
                headerContentCache,
                rootIdx,
                descriptor
            )

            nextMountedRows[rootIdx] = {
                Scope = rowScope,
                Descriptor = descriptor,
                Instance = rowInstance
            }
            nextRenderedRows[rootIdx] = rowInstance
        end

        renderedRows:set(nextRenderedRows)
        mountedRows = nextMountedRows
    end

    Observer(scope, visibleDescriptors):onBind(reconcileRows)
    return renderedRows
end

local function ComputeTopSpacerHeight(
    scope: Fusion.Scope,
    config: VirtualRowsConfig
): Fusion.Computed<number>
    return Computed(scope, function(use: Fusion.Use): number
        if not config.VisibleRootRange then return 0 end

        local visibleRange = use<<Vector2>>(config.VisibleRootRange)
        if visibleRange.X > visibleRange.Y then return 0 end

        local skippedCount = math.max(visibleRange.X - 1, 0)
        if skippedCount == 0 then return 0 end

        local rootGeometry =
            use<<RootRowGeometry>>(config.Layout.RootGeometry)

        local headerPinned =
            config.Header ~= nil
            and use<<boolean>>(config.ShowOnTop)

        return VirtualizationMath.CalculateTopSpacerHeight(
            rootGeometry,
            visibleRange.X,
            headerPinned,
            RowGap
        )
    end)
end

local function CreateTopSpacer(
    scope: Fusion.Scope,
    config: VirtualRowsConfig,
    height: Fusion.Computed<number>
): Instance
    return New(scope, "Frame") {
        Size = Computed(scope, function(use: Fusion.Use): UDim2
            return UDim2.new(1, 0, 0, use<<number>>(height))
        end),
        BackgroundTransparency = 1,
        LayoutOrder = Computed(scope, function(use: Fusion.Use): number
            if not config.VisibleRootRange then return 0 end
            return use<<Vector2>>(config.VisibleRootRange).X - 1
        end),
        Visible = Computed(scope, function(use: Fusion.Use): boolean
            return use<<number>>(height) > 0
        end),
        Name = "CulledMapRowsSpacer"
    }
end

local function ComputeRows(
    scope: Fusion.Scope,
    config: VirtualRowsConfig
): (Fusion.Child, Fusion.Value<RenderedRows>)
    local headerContentCache =
        if config.Header
        then CreateHeaderContentCache(
            scope,
            config.HeaderChildren,
            config.HeaderOverlay
        )
        else nil
    local visibleDescriptors = ComputeVisibleRootDescriptors(scope, config)
    local renderedRows = CreateRenderedRows(
        scope,
        config,
        visibleDescriptors,
        headerContentCache
    )
    local spacerHeight = ComputeTopSpacerHeight(scope, config)
    local topSpacer = CreateTopSpacer(scope, config, spacerHeight)

    local renderedRowsChild = (renderedRows :: unknown) :: Fusion.Child
    local rowChildren: { [unknown]: Fusion.Child } = {
        topSpacer,
        renderedRowsChild
    }

    return rowChildren, renderedRows
end

local function ComputeVirtualizedRows(
    scope: Fusion.Scope,
    config: VirtualRowsConfig
): Fusion.Computed<Fusion.Child>
    local rowChildren, renderedRows = ComputeRows(scope, config)

    return Computed(scope, function(use: Fusion.Use): Fusion.Child
        local usedRowHeight = use<<number>>(config.RowHeight)
        local isFullyCollapsed =
            use<<boolean>>(config.CollapsedState)
            and use<<UDim2>>(config.AnimatedMapSize).Height.Offset
                == usedRowHeight

        if isFullyCollapsed then
            local usedRenderedRows = use<<RenderedRows>>(renderedRows)
            local headerRow = usedRenderedRows[1]
            return if config.Header and headerRow then headerRow else {}
        end

        return rowChildren
    end)
end

return {
    CalculateMapHeight = CalculateMapHeight,
    CreateMapLayout = CreateMapLayout,
    CreateMapSizeTween = CreateMapSizeTween,
    ComputeVirtualListVisibleRootRange =
        ComputeVirtualListVisibleRootRange,
    ComputeVirtualizedRows = ComputeVirtualizedRows
}
