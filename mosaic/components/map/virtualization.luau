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
local MapEmptyItem = require(script.Parent.emptyItem)

local RowGap = 1
local MapContentPadding = 1

type Item = Types.Item
type Items = Types.Items
type TrySetValue<T> = Types.TrySetValue<T>
type IntrinsicAccessor = Types.IntrinsicAccessor
type IntrinsicItem = Types.IntrinsicItem
type IntrinsicItems = Types.IntrinsicItems
type ItemDefinition = Item | IntrinsicItem
type ItemLayout = Types.ItemLayout
type RowMetadata = Types.RowMetadata
type RootRowDescriptor = ItemLayout | string
type RootRowDescriptors = { [number]: RootRowDescriptor }
type RenderedRows = { [number]: Instance }
type HeaderChildrenCache = {
    CacheParent: Folder,
    Frame: Frame
}
type ResolvedItem = {
    Item: ItemDefinition,
    RootItem: Item,
    RootValue: any,
    ResolvedValue: any,
    ValueAccessor: IntrinsicAccessor?,
    TrySetValue: TrySetValue<any>?,
    Writable: boolean
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
    FocusedRootRange: Fusion.UsedAs<Vector2>,
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
    HideValues: boolean,
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

local function CreateHeaderChildrenCache(
    scope: Fusion.Scope,
    headerChildren: { Fusion.Child }?
): HeaderChildrenCache?
    if not headerChildren or next(headerChildren) == nil then return nil end

    local cacheParent = New(scope, "Folder") {
        Name = "MapHeaderChildrenCache"
    } :: Folder
    local frame = New(scope, "Frame") {
        Parent = cacheParent,
        Size = UDim2.fromScale(0, 1),
        AutomaticSize = Enum.AutomaticSize.X,
        BackgroundTransparency = 1,
        LayoutOrder = 2,

        Name = "HeaderChildren",

        [Children] = ({
            headerChildren,

            New(scope, "UIListLayout") {
                Padding = UDim.new(0, 6),
                FillDirection = Enum.FillDirection.Horizontal,
                HorizontalAlignment = Enum.HorizontalAlignment.Right,
                VerticalAlignment = Enum.VerticalAlignment.Center
            }
        } :: { Fusion.Child })
    } :: Frame

    return {
        CacheParent = cacheParent,
        Frame = frame
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
    return {
        Item = item,
        RootItem = item,
        RootValue = item.Value,
        ResolvedValue = item.Value,
        ValueAccessor = nil,
        TrySetValue = item.TrySetValue,
        Writable = item.Writable ~= false
    }
end

local function ResolveIntrinsicItem(
    item: IntrinsicItem,
    rootItem: Item,
    rootValue: any,
    parentWritable: boolean
): ResolvedItem
    local valueAccessor = item.Value
    local writeValue = valueAccessor.Write
    local trySetRootValue = rootItem.TrySetValue
    local trySetValue: TrySetValue<any>? = nil

    if parentWritable and trySetRootValue then
        trySetValue = function(value: any): (boolean, string?)
            local nextRootValue = writeValue(
                rootItem.Value,
                value
            )

            return trySetRootValue(nextRootValue)
        end
    end

    return {
        Item = item,
        RootItem = rootItem,
        RootValue = rootValue,
        ResolvedValue = valueAccessor.Read(rootValue),
        ValueAccessor = valueAccessor,
        TrySetValue = trySetValue,
        Writable = parentWritable
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
                item.Writable
            )
        end

        return childItems
    end

    local intrinsicItems: IntrinsicItems =
        IntrinsicSubItems[typeof(item.ResolvedValue)] or {}
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
            item.Writable
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
    local valueFocusState = Value<<boolean>>(scope, false)

    return {
        Item = item,
        ResolvedValue = resolvedItem.ResolvedValue,
        TrySetValue = resolvedItem.TrySetValue,
        Writable = resolvedItem.Writable,
        ValueFocusState = valueFocusState,
        Depth = depth,
        CanBecomeMapBottom = canBecomeMapBottom,
        CollapsedState = collapsedState,
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
    if use<<boolean>>(layout.ValueFocusState) then return true end

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

    local animatedExpandedHeight = Computed(
        mapLayoutScope,
        function(use: Fusion.Use): number
            local usedRootRows = use<<RootRowDescriptors>>(rootRows)
            local usedRowHeight = use<<number>>(rowHeight)
            local height = MapContentPadding

            for _, descriptor in usedRootRows do
                if descriptor == HeaderRowDescriptor
                    or descriptor == EmptyRowDescriptor
                then
                    height += usedRowHeight
                else
                    height += use<<number>>(
                        (descriptor :: ItemLayout).AnimatedHeight
                    )
                end

                height += RowGap
            end

            return height
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
        FocusedRootRange = focusedRootRange,
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
    layout: MapLayout,
    rowHeight: Fusion.UsedAs<number>
): Fusion.Computed<Vector2>?
    if not virtualListData then return nil end

    return Computed(scope, function(use: Fusion.Use): Vector2
        local focusedRootRange =
            use<<Vector2>>(layout.FocusedRootRange)

        if not use<<boolean>>(virtualListData.GeometryReady) then
            return focusedRootRange
        end

        local rootRows = use<<RootRowDescriptors>>(layout.RootRows)
        if #rootRows == 0 then return focusedRootRange end

        local mapCanvasTop = use<<number>>(virtualListData.MapCanvasTop)
        local canvasPosition =
            use<<Vector2>>(virtualListData.ViewportCanvasPosition)
        local viewportSize =
            use<<Vector2>>(virtualListData.ViewportAbsoluteSize)
        local overdraw = math.max(
            use<<number>>(virtualListData.Overdraw),
            0
        )

        local viewportTop = canvasPosition.Y - overdraw
        local viewportBottom = canvasPosition.Y + viewportSize.Y + overdraw
        local rowTop = mapCanvasTop + MapContentPadding
        local firstRow, lastRow: number? = nil, nil

        local usedRowHeight = use<<number>>(rowHeight)

        for rootIdx, descriptor in rootRows do
            local height = UseRootRowHeight(use, descriptor, usedRowHeight)
            local rowBottom = rowTop + height

            if rowBottom > viewportTop and rowTop < viewportBottom then
                firstRow = firstRow or rootIdx
                lastRow = rootIdx
            elseif firstRow and rowTop >= viewportBottom then
                break
            end

            rowTop = rowBottom + RowGap
        end

        local visibleRootRange =
            if firstRow and lastRow
            then Vector2.new(firstRow, lastRow)
            else Vector2.new(1, 0)

        return UnionRootRanges(visibleRootRange, focusedRootRange)
    end)
end

local function CreateRow(
    scope: Fusion.Scope,
    config: VirtualRowsConfig,
    headerChildrenCache: HeaderChildrenCache?,
    rootIdx: number,
    descriptor: RootRowDescriptor
): Instance
    local rowCount = config.Layout.RowCount

    if descriptor == HeaderRowDescriptor then
        if headerChildrenCache then
            local cache = headerChildrenCache

            -- MapHeader's cleanup unparents the frame first. Since scopes clean
            -- up in reverse order, this earlier task then returns it to cache.
            table.insert(scope, function()
                cache.Frame.Parent = cache.CacheParent
            end)
        end

        return MapHeader(scope, {
            Header = config.Header :: string,
            HeaderChildrenFrame = (
                if headerChildrenCache then headerChildrenCache.Frame else {}
            ) :: Fusion.Child,
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
        RowMetadata = config.Layout.Metadata,
        HideValue = config.HideValues
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
        if firstRow > lastRow then return descriptors end

        for rootIdx = firstRow, lastRow do
            local descriptor = rootRows[rootIdx]
            if descriptor then descriptors[rootIdx] = descriptor end
        end

        return descriptors
    end)
end

local function CreateRenderedRows(
    scope: Fusion.Scope,
    config: VirtualRowsConfig,
    visibleDescriptors: Fusion.Computed<RootRowDescriptors>,
    headerChildrenCache: HeaderChildrenCache?
): Fusion.Value<RenderedRows>
    local renderedRows = Fusion.Value<<RenderedRows>>(scope, {})
    local mountedRows = {} :: { [number]: MountedRow }

    local function reconcileRows()
        local descriptors = Peek<<RootRowDescriptors>>(visibleDescriptors)
        local nextMountedRows = {} :: { [number]: MountedRow }
        local nextRenderedRows = {} :: RenderedRows

        for rootIdx, descriptor in descriptors do
            local mountedRow = mountedRows[rootIdx]

            if mountedRow and mountedRow.Descriptor == descriptor then
                nextMountedRows[rootIdx] = mountedRow
                nextRenderedRows[rootIdx] = mountedRow.Instance
                continue
            end

            local rowScope = Fusion.innerScope(scope)
            local rowInstance = CreateRow(
                rowScope,
                config,
                headerChildrenCache,
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

        for rootIdx, mountedRow in mountedRows do
            if nextMountedRows[rootIdx] ~= mountedRow then
                Fusion.doCleanup(mountedRow.Scope)
            end
        end

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

        local rootRows = use<<RootRowDescriptors>>(config.Layout.RootRows)
        local rowHeight = use<<number>>(config.RowHeight) - 2
        local height = RowGap * (skippedCount - 1)

        for rootIdx = 1, skippedCount do
            height += UseRootRowHeight(use, rootRows[rootIdx], rowHeight)
        end

        return height
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
    local headerChildrenCache =
        if config.Header
        then CreateHeaderChildrenCache(scope, config.HeaderChildren)
        else nil
    local visibleDescriptors = ComputeVisibleRootDescriptors(scope, config)
    local renderedRows = CreateRenderedRows(
        scope,
        config,
        visibleDescriptors,
        headerChildrenCache
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
