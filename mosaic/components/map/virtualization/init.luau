--!strict

local Packages = script.Parent.Parent.Parent.Parent

local Fusion = require(Packages.fusion)
local Children, Computed, New, Observer, Peek, Tween, Value =
    Fusion.Children, Fusion.Computed, Fusion.New, Fusion.Observer,
    Fusion.peek, Fusion.Tween, Fusion.Value
local ProfileBegin, ProfileEnd =
    (debug :: any).profilebegin, (debug :: any).profileend

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
type TryTransformValue = Types.TryTransformValue
type IntrinsicAccessor = Types.IntrinsicAccessor
type IntrinsicItem = Types.IntrinsicItem
type IntrinsicItems = Types.IntrinsicItems
type ItemDefinition = Item | IntrinsicItem
type ItemLayout = Types.ItemLayout
type RowMetadata = Types.RowMetadata
type LazyRootRowDescriptor = {
    Kind: "LazyItem",
    ItemIdx: number
}
type RootRowDescriptor =
    ItemLayout | LazyRootRowDescriptor | string
type RootRowDescriptors = { [number]: RootRowDescriptor }
type RootRowGeometry = VirtualizationMath.RowGeometry
type RootRange = VirtualizationMath.RootRange
type RenderedRows = { [number]: Instance }
type RenderedRootPlan = {
    Descriptors: RootRowDescriptors,
    Gaps: { RootRange }
}
type LoadedItemLayouts = { [number]: ItemLayout }
type LoadItem = (
    scope: Fusion.Scope,
    itemIdx: number
) -> Item
type HeaderContentCache = {
    CacheParent: Folder,
    ChildrenFrame: Frame,
    OverlayFrame: Frame
}
type ResolvedItem = {
    Item: ItemDefinition,
    RootItem: Item,
    RootValue: Fusion.UsedAs<any?>,
    RootValues: { Fusion.UsedAs<any?> },
    ResolvedValue: Fusion.UsedAs<any?>,
    ValueType: Types.ValueType?,
    Mixed: Fusion.UsedAs<boolean>,
    ValueAccessor: IntrinsicAccessor?,
    TrySetKey: TrySet<string>?,
    TrySetValue: TrySet<any>?,
    TryTransformValue: TryTransformValue?,
    KeyWritable: boolean,
    ValueWritable: boolean,
    DisplayAsWritable: boolean,
    Warning: boolean
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

export type LazyMapLayout = MapLayout & {
    LoadRootRange: (
        firstRootRow: number,
        lastRootRow: number
    ) -> ()
}

export type VirtualListData = {
    Layout: MapLayout,
    AnimatedMapSize: Fusion.UsedAs<UDim2>?,
    MapReveal: Fusion.UsedAs<number>?,
    GeometryReady: Fusion.UsedAs<boolean>,
    VisibleRootRange: Fusion.UsedAs<Vector2>,
    _PerformanceSink: ((event: string, rootIdx: number?) -> ())?
}

export type VirtualRowsConfig = {
    Variant: ThemeUtils.BgVariantLayer,
    Header: string?,
    HeaderColors: Types.HeaderColors?,
    HeaderChildren: { Fusion.Child }?,
    HeaderOverlay: Fusion.Child?,
    HeaderZIndex: Fusion.UsedAs<number>,
    ShowOnTop: Fusion.UsedAs<boolean>,
    EmptyText: string?,
    Layout: MapLayout,
    Collapsible: boolean,
    CollapsedState: Fusion.Value<boolean>,
    AnimatedMapSize: Fusion.UsedAs<UDim2>,
    VisibleRootRange: Fusion.UsedAs<Vector2>?,
    RowHeight: Fusion.UsedAs<number>,
    _PerformanceSink: ((event: string, rootIdx: number?) -> ())?
}

type MountedRow = {
    Scope: Fusion.Scope,
    Descriptor: RootRowDescriptor,
    Instance: Instance
}
type MountedSpacer = {
    Scope: Fusion.Scope,
    LastRow: number,
    Instance: Instance
}

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

local function ComputeMixed(
    scope: Fusion.Scope,
    values: { Fusion.UsedAs<any?> },
    readValue: ((any) -> any)?
): Fusion.UsedAs<boolean>
    if #values <= 1 then return false end

    return Computed(scope, function(use: Fusion.Use): boolean
        local firstValue = use<<any?>>(values[1])
        if readValue then firstValue = readValue(firstValue) end

        for valueIdx = 2, #values do
            local value = use<<any?>>(values[valueIdx])
            if readValue then value = readValue(value) end
            if value ~= firstValue then return true end
        end

        return false
    end)
end

local function ResolveItem(
    scope: Fusion.Scope,
    item: Item
): ResolvedItem
    local trySetKey = item.TrySetKey
    local trySetValue = item.TrySetValue
    local tryTransformValue = item.TryTransformValue
    local valueType = item.ValueType
    -- Value changes are leaf updates. Peek deliberately avoids making the
    -- structural layout Computed depend on them.
    local currentValue = Peek<<any?>>(item.Value)
    local keyWritable =
        item.KeyWritable ~= false and
        trySetKey ~= nil
    local valueWritable =
        item.ValueWritable ~= false and
        trySetValue ~= nil

    if valueType == nil and currentValue ~= nil then
        valueType = typeof(currentValue)
    end
    local rootValues = item.ComparisonValues or { item.Value }

    return {
        Item = item,
        RootItem = item,
        RootValue = item.Value,
        RootValues = rootValues,
        ResolvedValue = item.Value,
        ValueType = valueType,
        Mixed = ComputeMixed(scope, rootValues, nil),
        ValueAccessor = nil,
        TrySetKey = if keyWritable then trySetKey else nil,
        TrySetValue = if valueWritable then trySetValue else nil,
        TryTransformValue =
            if valueWritable then tryTransformValue else nil,
        KeyWritable = keyWritable,
        ValueWritable = valueWritable,
        DisplayAsWritable =
            keyWritable or valueWritable or item.DisplayAsWritable == true,
        Warning = item.Warning == true
    }
end

local function ResolveIntrinsicItem(
    scope: Fusion.Scope,
    item: IntrinsicItem,
    rootItem: Item,
    rootValue: Fusion.UsedAs<any?>,
    rootValues: { Fusion.UsedAs<any?> },
    parentValueWritable: boolean,
    parentDisplayAsWritable: boolean,
    parentWarning: boolean
): ResolvedItem
    local valueAccessor = item.Value
    local writeValue = valueAccessor.Write
    local resolvedValue = Computed(scope, function(use: Fusion.Use): any
        return valueAccessor.Read(use<<any>>(rootValue))
    end)
    local currentResolvedValue = Peek<<any>>(resolvedValue)
    local trySetRootValue = rootItem.TrySetValue
    local tryTransformRootValue = rootItem.TryTransformValue
    local trySetValue: TrySet<any>? = nil

    if parentValueWritable and (tryTransformRootValue or trySetRootValue) then
        trySetValue = function(value: any): (boolean, string?, any?)
            local success: boolean
            local err: string?
            local savedRootValue: any?

            if tryTransformRootValue then
                success, err, savedRootValue =
                    tryTransformRootValue(function(currentRoot: any): any
                        return writeValue(currentRoot, value)
                    end)
            else
                local nextRootValue = writeValue(
                    Peek<<any>>(rootValue),
                    value
                )
                success, err, savedRootValue =
                    (trySetRootValue :: TrySet<any>)(nextRootValue)
            end

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
        RootValues = rootValues,
        ResolvedValue = resolvedValue,
        ValueType = typeof(currentResolvedValue),
        Mixed = ComputeMixed(scope, rootValues, valueAccessor.Read),
        ValueAccessor = valueAccessor,
        TrySetKey = nil,
        TrySetValue = trySetValue,
        TryTransformValue = tryTransformRootValue,
        KeyWritable = false,
        ValueWritable = parentValueWritable,
        DisplayAsWritable = parentDisplayAsWritable,
        Warning = parentWarning
    }
end

local function GetChildItems(
    scope: Fusion.Scope,
    item: ResolvedItem
): { ResolvedItem }
    if item.ValueAccessor then
        local intrinsicParent = item.Item :: IntrinsicItem
        local intrinsicItems: IntrinsicItems =
            intrinsicParent.SubItems or {}
        local childItems = table.create(#intrinsicItems) :: { ResolvedItem }

        for childIdx, childItem in intrinsicItems do
            childItems[childIdx] = ResolveIntrinsicItem(
                scope,
                childItem,
                item.RootItem,
                item.RootValue,
                item.RootValues,
                item.ValueWritable,
                item.DisplayAsWritable,
                item.Warning
            )
        end

        return childItems
    end

    local valueType = item.ValueType
    local intrinsicItems: IntrinsicItems =
        if type(valueType) == "string"
        then IntrinsicSubItemDefinitions[valueType] or {}
        else {}
    local suppliedParent = item.Item :: Item
    local suppliedMapItems: Items = suppliedParent.SubItems or {}
    local childItems = table.create(
        #intrinsicItems + #suppliedMapItems
    ) :: { ResolvedItem }

    for childIdx, childItem in intrinsicItems do
        childItems[childIdx] = ResolveIntrinsicItem(
            scope,
            childItem,
            item.RootItem,
            item.RootValue,
            item.RootValues,
            item.ValueWritable,
            item.DisplayAsWritable,
            item.Warning
        )
    end

    for childIdx, childItem in suppliedMapItems do
        childItems[#intrinsicItems + childIdx] =
            ResolveItem(scope, childItem)
    end

    return childItems
end

local function CreateItemLayout(
    scope: Fusion.Scope,
    collapseStateNode: CollapseStateNode,
    resolvedItem: ResolvedItem,
    depth: number,
    rowHeight: Fusion.UsedAs<number>,
    canBecomeMapBottom: boolean
): ItemLayout
    local item = resolvedItem.Item
    local childItems = GetChildItems(scope, resolvedItem)
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

    local hasChildren = #children > 0
    local childrenContentHeight: Fusion.UsedAs<number> = 0

    if hasChildren then
        childrenContentHeight = Computed(
            scope,
            function(use: Fusion.Use): number
                local height = 0

                for childIdx, child in children do
                    if childIdx > 1 then height += RowGap end
                    height += use<<number>>(child.AnimatedHeight)
                end

                return height
            end
        )
    end

    local collapsedState: Fusion.Value<boolean>? = nil
    if hasChildren then
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

    local animatedChildrenHeight: Fusion.UsedAs<number> = 0

    if reveal then
        local animatedReveal = reveal
        animatedChildrenHeight = Computed(
            scope,
            function(use: Fusion.Use): number
                return use<<number>>(animatedReveal)
                    * (RowGap + use<<number>>(childrenContentHeight))
            end
        )
    end

    local cornersCollapsed: Fusion.Computed<boolean>? = nil
    if reveal then
        local animatedReveal = reveal
        cornersCollapsed = Computed(scope, function(use: Fusion.Use): boolean
            return use<<number>>(animatedReveal) == 0
        end)
    end

    local animatedHeight: Fusion.UsedAs<number> = rowHeight

    if reveal then
        animatedHeight = Computed(scope, function(use: Fusion.Use): number
            return use<<number>>(rowHeight)
                + use<<number>>(animatedChildrenHeight)
        end)
    end

    local keyFocusState: Fusion.Value<boolean>? =
        if resolvedItem.KeyWritable
        then Value<<boolean>>(scope, false)
        else nil
    local keyFocusElevationState: Fusion.Value<boolean>? =
        if resolvedItem.KeyWritable
        then Value<<boolean>>(scope, false)
        else nil
    local valueFocusable =
        resolvedItem.ValueType ~= nil and resolvedItem.ValueWritable
    local valueFocusState: Fusion.Value<boolean>? =
        if valueFocusable
        then Value<<boolean>>(scope, false)
        else nil
    local valueFocusElevationState: Fusion.Value<boolean>? =
        if valueFocusable
        then Value<<boolean>>(scope, false)
        else nil

    return {
        Item = item,
        ResolvedValue = resolvedItem.ResolvedValue,
        ValueType = resolvedItem.ValueType,
        Mixed = resolvedItem.Mixed,
        TrySetKey = resolvedItem.TrySetKey,
        TrySetValue = resolvedItem.TrySetValue,
        KeyWritable = resolvedItem.KeyWritable,
        ValueWritable = resolvedItem.ValueWritable,
        DisplayAsWritable = resolvedItem.DisplayAsWritable,
        Warning = resolvedItem.Warning,
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
    local keyFocusState = layout.KeyFocusState
    if keyFocusState and use<<boolean>>(keyFocusState) then return true end

    local keyFocusElevationState = layout.KeyFocusElevationState
    if keyFocusElevationState
        and use<<boolean>>(keyFocusElevationState)
    then
        return true
    end

    local valueFocusState = layout.ValueFocusState
    if valueFocusState and use<<boolean>>(valueFocusState) then return true end

    local valueFocusElevationState = layout.ValueFocusElevationState
    if valueFocusElevationState
        and use<<boolean>>(valueFocusElevationState)
    then
        return true
    end

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

    if type(descriptor) == "table"
        and (descriptor :: any).Kind == "LazyItem"
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
                ResolveItem(layoutScope, item),
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
                    local keyFocusState = itemLayout.KeyFocusState
                    local valueFocusState = itemLayout.ValueFocusState

                    return
                        (
                            keyFocusState ~= nil
                            and use<<boolean>>(keyFocusState)
                        )
                        or (
                            valueFocusState ~= nil
                            and use<<boolean>>(valueFocusState)
                        )
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

local function ComputeLazyRowMetadata(
    scope: Fusion.Scope,
    loadedLayouts: Fusion.Value<LoadedItemLayouts>,
    header: string?,
    itemCount: number,
    emptyText: string?,
    useAnimatedCollapse: boolean
): Fusion.Computed<RowMetadata>
    return Computed(scope, function(use: Fusion.Use): RowMetadata
        local usedLayouts =
            use<<LoadedItemLayouts>>(loadedLayouts)
        local rowIndices = {} :: { [ItemLayout]: number }
        local rowCount = if header then 1 else 0

        local function visit(layout: ItemLayout)
            rowCount += 1
            rowIndices[layout] = rowCount

            local collapsedState =
                if useAnimatedCollapse then layout.CornersCollapsed
                else layout.CollapsedState

            if collapsedState and use<<boolean>>(collapsedState) then
                return
            end

            for _, child in layout.Children do visit(child) end
        end

        if itemCount > 0 then
            for itemIdx = 1, itemCount do
                local layout = usedLayouts[itemIdx]

                if layout then
                    visit(layout)
                else
                    rowCount += 1
                end
            end
        elseif emptyText then
            rowCount += 1
        end

        return {
            RowCount = rowCount,
            RowIndices = rowIndices
        }
    end)
end

local function CreateLazyMapLayout(
    scope: Fusion.Scope,
    detailStateScope: Fusion.Scope,
    header: string?,
    itemCount: number,
    emptyText: string?,
    rowHeight: Fusion.UsedAs<number>,
    loadItem: LoadItem
): LazyMapLayout
    -- Shape data is enough to position every root row. Detail layouts are
    -- added sparsely as VirtualMapScrollable publishes visible ranges.
    local collapseStateRoot: CollapseStateNode = {
        IsCollapsed = nil,
        Children = {}
    }
    local loadedLayouts = {} :: LoadedItemLayouts
    local loadedLayoutsState =
        Value<<LoadedItemLayouts>>(scope, {})
    local lazyDescriptors =
        table.create(itemCount) :: { LazyRootRowDescriptor }

    for itemIdx = 1, itemCount do
        lazyDescriptors[itemIdx] = {
            Kind = "LazyItem",
            ItemIdx = itemIdx
        }
    end

    table.insert(scope, function()
        table.clear(collapseStateRoot.Children)
        table.clear(loadedLayouts)
    end)

    local rootRows = Computed(
        scope,
        function(use: Fusion.Use): RootRowDescriptors
            local usedLayouts =
                use<<LoadedItemLayouts>>(loadedLayoutsState)
            local rows =
                table.create(itemCount + 1) :: RootRowDescriptors

            if header then table.insert(rows, HeaderRowDescriptor) end

            if itemCount > 0 then
                for itemIdx = 1, itemCount do
                    table.insert(
                        rows,
                        usedLayouts[itemIdx]
                            or lazyDescriptors[itemIdx]
                    )
                end
            elseif emptyText then
                table.insert(rows, EmptyRowDescriptor)
            end

            return rows
        end
    )

    local focusedRootRange = Computed(
        scope,
        function(use: Fusion.Use): Vector2
            local usedLayouts =
                use<<LoadedItemLayouts>>(loadedLayoutsState)
            local headerOffset = if header then 1 else 0
            local firstRow, lastRow: number? = nil, nil

            for itemIdx, layout in usedLayouts do
                if not UseItemTreeFocus(use, layout) then continue end

                local rootIdx = headerOffset + itemIdx
                firstRow = if firstRow
                    then math.min(firstRow, rootIdx)
                    else rootIdx
                lastRow = if lastRow
                    then math.max(lastRow, rootIdx)
                    else rootIdx
            end

            if not firstRow or not lastRow then
                return Vector2.new(1, 0)
            end

            return Vector2.new(firstRow, lastRow)
        end
    )

    local rootGeometry = Computed(
        scope,
        function(use: Fusion.Use): RootRowGeometry
            ProfileBegin("VirtualMapScrollable.RootGeometry")

            local usedRootRows =
                use<<RootRowDescriptors>>(rootRows)
            local usedRowHeight = use<<number>>(rowHeight)
            local rowHeights =
                table.create(#usedRootRows) :: { number }

            for rootIdx, descriptor in usedRootRows do
                rowHeights[rootIdx] = UseRootRowHeight(
                    use,
                    descriptor,
                    usedRowHeight
                )
            end

            local geometry = VirtualizationMath.BuildRowGeometry(
                rowHeights,
                MapContentPadding,
                RowGap
            )

            ProfileEnd()
            return geometry
        end
    )

    local animatedExpandedHeight = Computed(
        scope,
        function(use: Fusion.Use): number
            return use<<RootRowGeometry>>(rootGeometry).TotalHeight
        end
    )
    local targetMetadata = ComputeLazyRowMetadata(
        scope,
        loadedLayoutsState,
        header,
        itemCount,
        emptyText,
        false
    )
    local metadata = ComputeLazyRowMetadata(
        scope,
        loadedLayoutsState,
        header,
        itemCount,
        emptyText,
        true
    )
    local lastRowFocused = Computed(
        scope,
        function(use: Fusion.Use): boolean
            local usedMetadata = use<<RowMetadata>>(metadata)
            local lastRowIdx = usedMetadata.RowCount

            for itemLayout, rowIdx in usedMetadata.RowIndices do
                if rowIdx ~= lastRowIdx then continue end

                local keyFocusState = itemLayout.KeyFocusState
                local valueFocusState = itemLayout.ValueFocusState

                return
                    (
                        keyFocusState ~= nil
                        and use<<boolean>>(keyFocusState)
                    )
                    or (
                        valueFocusState ~= nil
                        and use<<boolean>>(valueFocusState)
                    )
            end

            return false
        end
    )
    local rowCount = Computed(scope, function(use: Fusion.Use): number
        return use<<RowMetadata>>(targetMetadata).RowCount
    end)
    local cornerRowCount = Computed(
        scope,
        function(use: Fusion.Use): number
            return use<<RowMetadata>>(metadata).RowCount
        end
    )

    local function loadRootRange(
        firstRootRow: number,
        lastRootRow: number
    )
        local firstItem, lastItem =
            VirtualizationMath.RootRangeToItemRange(
                firstRootRow,
                lastRootRow,
                header ~= nil,
                itemCount
            )
        local changed = false

        for itemIdx = firstItem, lastItem do
            if loadedLayouts[itemIdx] then continue end

            local item = loadItem(detailStateScope, itemIdx)

            assert(
                type(item) == "table"
                    and type(item.Key) == "string",
                `Detail must return a Map.Item for row {itemIdx}.`
            )

            local collapseStateNode = GetCollapseStateNode(
                collapseStateRoot,
                item
            )
            loadedLayouts[itemIdx] = CreateItemLayout(
                detailStateScope,
                collapseStateNode,
                ResolveItem(detailStateScope, item),
                1,
                rowHeight,
                itemIdx == itemCount
            )
            changed = true
        end

        if changed then
            -- Loaded rows remain cached for this shape's lifetime. This keeps
            -- expanded, focused, and edited row state stable across scrolling.
            loadedLayoutsState:set(table.clone(loadedLayouts))
        end
    end

    return {
        RootItems = (loadedLayoutsState :: any),
        RootRows = rootRows,
        RootGeometry = rootGeometry,
        FocusedRootRange = focusedRootRange,
        LastRowFocused = lastRowFocused,
        AnimatedExpandedHeight = animatedExpandedHeight,
        Metadata = metadata,
        CornerRowCount = cornerRowCount,
        RowCount = rowCount,
        LoadRootRange = loadRootRange
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

local function ComputeVirtualListVisibleRootRange(
    scope: Fusion.Scope,
    virtualListData: VirtualListData?
): Fusion.Computed<Vector2>?
    if not virtualListData then return nil end

    return Computed(scope, function(use: Fusion.Use): Vector2
        if not use<<boolean>>(virtualListData.GeometryReady) then
            return Vector2.new(1, 0)
        end

        return use<<Vector2>>(virtualListData.VisibleRootRange)
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
        local headerColors = assert(
            config.HeaderColors,
            "Header rows must have resolved colors."
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
            HeaderColors = headerColors,
            HeaderChildrenFrame = cache.ChildrenFrame,
            HeaderOverlayFrame = cache.OverlayFrame,
            ZIndex = config.HeaderZIndex,
            RowCount = rowCount,
            RowIdx = 1,
            Collapsible = config.Collapsible,
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

    assert(
        not (
            type(descriptor) == "table"
            and (descriptor :: any).Kind == "LazyItem"
        ),
        `Lazy map row {rootIdx} was rendered before its detail was loaded.`
    )

    return MapItem(scope, {
        Variant = config.Variant,
        Layout = descriptor :: ItemLayout,
        LayoutOrder = rootIdx,
        RowCount = config.Layout.CornerRowCount,
        RowMetadata = config.Layout.Metadata
    })
end

local function ComputeRenderedRootPlan(
    scope: Fusion.Scope,
    config: VirtualRowsConfig
): Fusion.Computed<RenderedRootPlan>
    return Computed(scope, function(use: Fusion.Use): RenderedRootPlan
        local rootRows = use<<RootRowDescriptors>>(config.Layout.RootRows)
        local rowCount = #rootRows
        local candidateRanges = {} :: { RootRange }

        if config.VisibleRootRange then
            local visibleRange = use<<Vector2>>(config.VisibleRootRange)
            table.insert(candidateRanges, {
                First = visibleRange.X,
                Last = visibleRange.Y
            })
        else
            table.insert(candidateRanges, {
                First = 1,
                Last = rowCount
            })
        end

        local focusedRange =
            use<<Vector2>>(config.Layout.FocusedRootRange)
        table.insert(candidateRanges, {
            First = focusedRange.X,
            Last = focusedRange.Y
        })

        if config.Header and use<<boolean>>(config.ShowOnTop) then
            table.insert(candidateRanges, {
                First = 1,
                Last = 1
            })
        end

        local renderedRanges =
            VirtualizationMath.MergeRootRanges(
                rowCount,
                candidateRanges
            )
        local descriptors = {} :: RootRowDescriptors

        for _, range in renderedRanges do
            for rootIdx = range.First, range.Last do
                local descriptor = rootRows[rootIdx]
                if descriptor then descriptors[rootIdx] = descriptor end
            end
        end

        return {
            Descriptors = descriptors,
            Gaps = VirtualizationMath.FindRootRangeGaps(
                renderedRanges
            )
        }
    end)
end

local function CreateRenderedRows(
    scope: Fusion.Scope,
    config: VirtualRowsConfig,
    renderedRootPlan: Fusion.Computed<RenderedRootPlan>,
    headerContentCache: HeaderContentCache?
): Fusion.Value<RenderedRows>
    local rowLifetimeScope = Fusion.innerScope(scope)
    local renderedRows = Fusion.Value<<RenderedRows>>(scope, {})
    local mountedRows = {} :: { [number]: MountedRow }
    local performanceSink = config._PerformanceSink
    local alive = true
    local reconciling = false
    local reconcilePending = false

    local function reconcileRowsOnce()
        if not alive then return end

        local descriptors = Peek<<RenderedRootPlan>>(
            renderedRootPlan
        ).Descriptors
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
            if not alive then return end

            if performanceSink then
                (performanceSink :: (event: string, rootIdx: number?) -> ())("RowUnmount", rootIdx)
            end
        end

        for rootIdx, descriptor in descriptors do
            if nextMountedRows[rootIdx] then continue end
            if not alive then return end

            local rowScope = Fusion.innerScope(rowLifetimeScope)
            local rowInstance = CreateRow(
                rowScope,
                config,
                headerContentCache,
                rootIdx,
                descriptor
            )
            if not alive then return end

            nextMountedRows[rootIdx] = {
                Scope = rowScope,
                Descriptor = descriptor,
                Instance = rowInstance
            }
            nextRenderedRows[rootIdx] = rowInstance

            if performanceSink then
                (performanceSink :: (event: string, rootIdx: number?) -> ())("RowMount", rootIdx)
            end
        end

        if not alive then return end
        renderedRows:set(nextRenderedRows)
        mountedRows = nextMountedRows
    end

    local function reconcileRows()
        if not alive then return end
        if reconciling then
            reconcilePending = true
            return
        end

        reconciling = true
        repeat
            reconcilePending = false
            reconcileRowsOnce()
        until not alive or not reconcilePending
        reconciling = false
    end

    local renderedRootPlanObserver =
        Observer(scope, renderedRootPlan)
    table.insert(scope, function()
        alive = false
        if not performanceSink then return end

        for rootIdx in mountedRows do
            performanceSink("RowUnmount", rootIdx)
        end
    end)
    -- Register the teardown guard before onBind queues its initial callback.
    renderedRootPlanObserver:onBind(reconcileRows)

    return renderedRows
end

local function CreateGapSpacer(
    scope: Fusion.Scope,
    config: VirtualRowsConfig,
    gap: RootRange
): Instance
    return New(scope, "Frame") {
        Size = Computed(scope, function(use: Fusion.Use): UDim2
            local geometry = use<<RootRowGeometry>>(
                config.Layout.RootGeometry
            )
            local height =
                VirtualizationMath.CalculateGapSpacerHeight(
                    geometry,
                    gap.First,
                    gap.Last
                )

            return UDim2.new(1, 0, 0, height)
        end),
        BackgroundTransparency = 1,
        LayoutOrder = gap.First,
        Name = `CulledMapRowsSpacer [{gap.First}-{gap.Last}]`
    }
end

local function CreateRenderedGapSpacers(
    scope: Fusion.Scope,
    config: VirtualRowsConfig,
    renderedRootPlan: Fusion.Computed<RenderedRootPlan>
): Fusion.Value<RenderedRows>
    local spacerLifetimeScope = Fusion.innerScope(scope)
    local renderedSpacers = Fusion.Value<<RenderedRows>>(scope, {})
    local mountedSpacers = {} :: { [number]: MountedSpacer }
    local alive = true
    local reconciling = false
    local reconcilePending = false

    local function reconcileSpacersOnce()
        if not alive then return end
        local gaps = Peek<<RenderedRootPlan>>(
            renderedRootPlan
        ).Gaps
        local nextMountedSpacers =
            {} :: { [number]: MountedSpacer }
        local nextRenderedSpacers = {} :: RenderedRows
        local changed = false

        for _, gap in gaps do
            local mountedSpacer = mountedSpacers[gap.First]

            if mountedSpacer
                and mountedSpacer.LastRow == gap.Last
            then
                nextMountedSpacers[gap.First] = mountedSpacer
                nextRenderedSpacers[gap.First] =
                    mountedSpacer.Instance
                continue
            end

            if mountedSpacer then
                Fusion.doCleanup(mountedSpacer.Scope)
                if not alive then return end
            end

            if not alive then return end
            local spacerScope =
                Fusion.innerScope(spacerLifetimeScope)
            local spacerInstance = CreateGapSpacer(
                spacerScope,
                config,
                gap
            )
            if not alive then return end

            nextMountedSpacers[gap.First] = {
                Scope = spacerScope,
                LastRow = gap.Last,
                Instance = spacerInstance
            }
            nextRenderedSpacers[gap.First] = spacerInstance
            changed = true
        end

        for firstRow, mountedSpacer in mountedSpacers do
            if nextMountedSpacers[firstRow] then continue end

            Fusion.doCleanup(mountedSpacer.Scope)
            if not alive then return end
            changed = true
        end

        if not changed then return end

        if not alive then return end
        renderedSpacers:set(nextRenderedSpacers)
        mountedSpacers = nextMountedSpacers
    end

    local function reconcileSpacers()
        if not alive then return end
        if reconciling then
            reconcilePending = true
            return
        end

        reconciling = true
        repeat
            reconcilePending = false
            reconcileSpacersOnce()
        until not alive or not reconcilePending
        reconciling = false
    end

    local renderedRootPlanObserver =
        Observer(scope, renderedRootPlan)
    table.insert(scope, function()
        alive = false
    end)
    -- Register the teardown guard before onBind queues its initial callback.
    renderedRootPlanObserver:onBind(reconcileSpacers)
    return renderedSpacers
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
    local renderedRootPlan = ComputeRenderedRootPlan(scope, config)
    local renderedRows = CreateRenderedRows(
        scope,
        config,
        renderedRootPlan,
        headerContentCache
    )
    local renderedSpacers = CreateRenderedGapSpacers(
        scope,
        config,
        renderedRootPlan
    )

    local renderedRowsChild = (renderedRows :: unknown) :: Fusion.Child
    local renderedSpacersChild =
        (renderedSpacers :: unknown) :: Fusion.Child
    local rowChildren: { [unknown]: Fusion.Child } = {
        renderedSpacersChild,
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
    CreateMapLayout = CreateMapLayout,
    CreateLazyMapLayout = CreateLazyMapLayout,
    CreateMapSizeTween = CreateMapSizeTween,
    ComputeVirtualListVisibleRootRange =
        ComputeVirtualListVisibleRootRange,
    ComputeVirtualizedRows = ComputeVirtualizedRows
}
