--!strict

local Packages = script.Parent.Parent.Parent.Parent

local Fusion = require(Packages.fusion)
local Computed, New, Observer, Peek, Tween =
    Fusion.Computed, Fusion.New, Fusion.Observer, Fusion.peek, Fusion.Tween

local Utils = script.Parent.Parent.Parent.utils
local ThemeUtils = require(Utils.themeUtils)

local Types = require(script.Parent.types)
local MapHeader = require(script.Parent.header)
local MapItem = require(script.Parent.item)
local MapEmptyItem = require(script.Parent.emptyItem)

local RowGap = 1
local MapContentPadding = 1
local MapTweenInfo = TweenInfo.new(
    0.18,
    Enum.EasingStyle.Exponential,
    Enum.EasingDirection.InOut
)

type Item = Types.Item
type Items = Types.Items
type RowDescriptor = Item | string
type RowDescriptors = { [number]: RowDescriptor }
type RenderedRows = { [number]: Instance }

local HeaderRowDescriptor: "Header" = "Header"
local EmptyRowDescriptor: "Empty" = "Empty"

export type VirtualListData = {
    AnimatedMapSize: Fusion.Tween<UDim2>?,
    RowCount: Fusion.Computed<number>?,
    GeometryReady: Fusion.UsedAs<boolean>,
    ViewportCanvasPosition: Fusion.UsedAs<Vector2>,
    ViewportAbsoluteSize: Fusion.UsedAs<Vector2>,
    MapCanvasTop: Fusion.UsedAs<number>,
    Overdraw: Fusion.UsedAs<number>
}

export type VirtualRowsConfig = {
    Variant: ThemeUtils.BgVariantLayer,
    Header: string?,
    Items: Fusion.UsedAs<Items>?,
    HideValues: boolean,
    EmptyText: string?,
    RowCount: Fusion.Computed<number>,
    CollapsedState: Fusion.Value<boolean>,
    AnimatedMapSize: Fusion.Tween<UDim2>,
    VisibleRowRange: Fusion.UsedAs<Vector2>?,
    RowHeight: number
}

type MountedRow = {
    Scope: Fusion.Scope,
    Descriptor: RowDescriptor,
    RowCount: number,
    Instance: Instance
}

local function CalculateMapRowCount(
    itemCount: number,
    hasHeader: boolean,
    hasEmptyText: boolean
): number
    local rowCount = if hasHeader then 1 else 0

    if itemCount > 0 then
        rowCount += itemCount

    elseif hasEmptyText then
        rowCount += 1
    end

    return rowCount
end

local function CalculateMapHeight(rowCount: number, lgHeight: number): number
    local rowHeight = lgHeight - 2

    return rowHeight * rowCount + rowCount + 1
end

local function CalculateMapTopSpacerHeight(
    skippedRowCount: number,
    lgHeight: number
): number
    if skippedRowCount <= 0 then return 0 end

    local rowHeight = lgHeight - 2

    return rowHeight * skippedRowCount + RowGap * (skippedRowCount - 1)
end

local function ComputeMapRowCount(
    scope: Fusion.Scope,
    header: string?,
    items: Fusion.UsedAs<Items>?,
    emptyText: string?
): Fusion.Computed<number>
    return Computed(scope, function(use: Fusion.Use): number
        local usedItems = if items then use<<Items>>(items) else nil

        return CalculateMapRowCount(
            if usedItems then #usedItems else 0,
            header ~= nil,
            emptyText ~= nil
        )
    end)
end

local function CreateMapSizeTween(
    scope: Fusion.Scope,
    width: UDim,
    collapsed: Fusion.UsedAs<boolean>,
    rowCount: Fusion.UsedAs<number>,
    lgHeight: number
): Fusion.Tween<UDim2>
    local targetSize = Computed(scope, function(use: Fusion.Use): UDim2
        local height =
            if use<<boolean>>(collapsed) then lgHeight
            else CalculateMapHeight(use<<number>>(rowCount), lgHeight)

        return UDim2.new(width, UDim.new(0, height))
    end)

    return Tween<<UDim2>>(scope, targetSize, MapTweenInfo)
end

local function ComputeVirtualListVisibleRowRange(
    scope: Fusion.Scope,
    virtualListData: VirtualListData?,
    rowCount: Fusion.UsedAs<number>,
    lgHeight: number
): Fusion.Computed<Vector2>?
    if not virtualListData then return nil end

    return Computed(scope, function(use: Fusion.Use): Vector2
        if not use<<boolean>>(virtualListData.GeometryReady) then
            return Vector2.new(1, 0)
        end

        local usedRowCount = use<<number>>(rowCount)
        if usedRowCount <= 0 then return Vector2.new(1, 0) end

        local usedMapCanvasTop =
            use<<number>>(virtualListData.MapCanvasTop)
        local usedViewportCanvasPosition =
            use<<Vector2>>(virtualListData.ViewportCanvasPosition)
        local usedViewportAbsoluteSize =
            use<<Vector2>>(virtualListData.ViewportAbsoluteSize)
        local usedOverdraw = math.max(
            use<<number>>(virtualListData.Overdraw),
            0
        )

        local rowHeight = lgHeight - 2
        local rowStride = rowHeight + RowGap
        local contentTopY = usedMapCanvasTop + MapContentPadding

        local viewportTopY = usedViewportCanvasPosition.Y - usedOverdraw
        local viewportBottomY = usedViewportCanvasPosition.Y
            + usedViewportAbsoluteSize.Y
            + usedOverdraw

        local firstRow = math.floor(
            (viewportTopY - contentTopY - rowHeight) / rowStride
        ) + 2

        local lastRow = math.ceil(
            (viewportBottomY - contentTopY) / rowStride
        )

        if lastRow < 1 or firstRow > usedRowCount or firstRow > lastRow then
            return Vector2.new(1, 0)
        end

        return Vector2.new(
            math.clamp(firstRow, 1, usedRowCount),
            math.clamp(lastRow, 1, usedRowCount)
        )
    end)
end

local function CreateRow(
    scope: Fusion.Scope,
    config: VirtualRowsConfig,
    rowIdx: number,
    descriptor: RowDescriptor,
    rowCount: number
): Instance
    if descriptor == HeaderRowDescriptor then
        return MapHeader(scope, {
            Header = config.Header :: string,
            Variant = config.Variant,
            RowCount = rowCount,
            RowIdx = rowIdx,
            CollapsedState = config.CollapsedState,
            TweenComputeMapSize = config.AnimatedMapSize
        })
    end

    if descriptor == EmptyRowDescriptor then
        return MapEmptyItem(scope, {
            Text = config.EmptyText :: string,
            Variant = config.Variant,
            RowCount = rowCount,
            RowIdx = rowIdx,
        })
    end

    local item = descriptor :: Item

    return MapItem(scope, {
        Key = item.Key,
        Value = item.Value,
        SubItems = item.SubItems,
        Nestedness = 0,
        HideValue = config.HideValues,
        Variant = config.Variant,
        RowCount = rowCount,
        RowIdx = rowIdx
    })
end

local function ComputeVisibleRowDescriptors(
    scope: Fusion.Scope,
    config: VirtualRowsConfig
): Fusion.Computed<RowDescriptors>
    local header = config.Header
    local items = config.Items
    local emptyText = config.EmptyText
    local rowCount = config.RowCount
    local visibleRowRange = config.VisibleRowRange

    return Computed(
        scope,
        function(use: Fusion.Use): RowDescriptors
            local usedRowCount = use<<number>>(rowCount)
            local usedItems = if items then use<<Items>>(items) else nil
            local firstRow, lastRow = 1, usedRowCount

            if visibleRowRange then
                local usedVisibleRowRange =
                    use<<Vector2>>(visibleRowRange)
                firstRow = usedVisibleRowRange.X
                lastRow = usedVisibleRowRange.Y
            end

            local descriptors = {} :: RowDescriptors
            if firstRow > lastRow then return descriptors end

            local baseIdx = if header then 1 else 0

            if header and firstRow <= 1 and lastRow >= 1 then
                descriptors[1] = HeaderRowDescriptor
            end

            if not usedItems or #usedItems == 0 then
                if not emptyText then return descriptors end

                local rowIdx = baseIdx + 1
                if rowIdx < firstRow or rowIdx > lastRow then
                    return descriptors
                end

                descriptors[rowIdx] = EmptyRowDescriptor
                return descriptors
            end

            local firstItemIdx = math.max(firstRow - baseIdx, 1)
            local lastItemIdx = math.min(lastRow - baseIdx, #usedItems)

            for itemIdx = firstItemIdx, lastItemIdx do
                local rowIdx = baseIdx + itemIdx
                -- Stable item references preserve rows as the range moves.
                descriptors[rowIdx] = usedItems[itemIdx]
            end

            return descriptors
        end
    )
end

local function CreateRenderedRows(
    scope: Fusion.Scope,
    config: VirtualRowsConfig,
    visibleRowDescriptors: Fusion.Computed<RowDescriptors>
): Fusion.Value<RenderedRows>
    local rowCount = config.RowCount
    local renderedRows = Fusion.Value<<RenderedRows>>(scope, {})
    local mountedRows = {} :: { [number]: MountedRow }

    local function reconcileRows()
        local descriptors = Peek<<RowDescriptors>>(visibleRowDescriptors)
        local usedRowCount = Peek<<number>>(rowCount)
        local nextMountedRows = {} :: { [number]: MountedRow }
        local nextRenderedRows = {} :: RenderedRows

        for rowIdx, descriptor in descriptors do
            local mountedRow = mountedRows[rowIdx]

            if mountedRow
                and mountedRow.Descriptor == descriptor
                and mountedRow.RowCount == usedRowCount
            then
                nextMountedRows[rowIdx] = mountedRow
                nextRenderedRows[rowIdx] = mountedRow.Instance
                continue
            end

            local rowScope = Fusion.innerScope(scope)
            local rowInstance = CreateRow(
                rowScope,
                config,
                rowIdx,
                descriptor,
                usedRowCount
            )
            local nextMountedRow: MountedRow = {
                Scope = rowScope,
                Descriptor = descriptor,
                RowCount = usedRowCount,
                Instance = rowInstance
            }

            nextMountedRows[rowIdx] = nextMountedRow
            nextRenderedRows[rowIdx] = rowInstance
        end

        -- Publish replacements before cleaning old scopes to avoid empty rows.
        renderedRows:set(nextRenderedRows)

        for rowIdx, mountedRow in mountedRows do
            if nextMountedRows[rowIdx] ~= mountedRow then
                Fusion.doCleanup(mountedRow.Scope)
            end
        end

        mountedRows = nextMountedRows
    end

    Observer(scope, visibleRowDescriptors):onBind(reconcileRows)

    return renderedRows
end

local function ComputeSkippedRowCount(
    scope: Fusion.Scope,
    visibleRowRange: Fusion.UsedAs<Vector2>?
): Fusion.Computed<number>
    return Computed(scope, function(use: Fusion.Use): number
        if not visibleRowRange then return 0 end

        local usedVisibleRowRange = use<<Vector2>>(visibleRowRange)
        if usedVisibleRowRange.X > usedVisibleRowRange.Y then return 0 end

        return math.max(usedVisibleRowRange.X - 1, 0)
    end)
end

local function CreateTopSpacer(
    scope: Fusion.Scope,
    skippedRowCount: Fusion.Computed<number>,
    rowHeight: number
): Instance
    return New(scope, "Frame") {
        Size = Computed(scope, function(use: Fusion.Use): UDim2
            local usedSkippedRowCount = use<<number>>(skippedRowCount)

            return UDim2.new(
                1,
                0,
                0,
                CalculateMapTopSpacerHeight(
                    usedSkippedRowCount,
                    rowHeight
                )
            )
        end),
        BackgroundTransparency = 1,
        LayoutOrder = Computed(scope, function(use: Fusion.Use): number
            return use<<number>>(skippedRowCount)
        end),
        Visible = Computed(scope, function(use: Fusion.Use): boolean
            return use<<number>>(skippedRowCount) > 0
        end),

        Name = "CulledMapRowsSpacer"
    }
end

local function ComputeRows(
    scope: Fusion.Scope,
    config: VirtualRowsConfig
): (Fusion.Child, Fusion.Value<RenderedRows>)
    local visibleRowDescriptors =
        ComputeVisibleRowDescriptors(scope, config)
    local renderedRows =
        CreateRenderedRows(scope, config, visibleRowDescriptors)
    local skippedRowCount =
        ComputeSkippedRowCount(scope, config.VisibleRowRange)
    local topSpacer =
        CreateTopSpacer(scope, skippedRowCount, config.RowHeight)

    -- Fusion.Child cannot express an instance dictionary state.
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
        local isFullyCollapsed =
            use<<boolean>>(config.CollapsedState)
            and use<<UDim2>>(config.AnimatedMapSize).Height.Offset
                == config.RowHeight

        if isFullyCollapsed then
            local usedRenderedRows =
                use<<{ [number]: Instance }>>(renderedRows)
            local headerRow = usedRenderedRows[1]

            return
                if config.Header and headerRow then headerRow
                else {}
        end

        return rowChildren
    end)
end

return {
    CalculateMapRowCount = CalculateMapRowCount,
    CalculateMapHeight = CalculateMapHeight,
    CalculateMapTopSpacerHeight = CalculateMapTopSpacerHeight,
    ComputeMapRowCount = ComputeMapRowCount,
    CreateMapSizeTween = CreateMapSizeTween,
    ComputeVirtualListVisibleRowRange = ComputeVirtualListVisibleRowRange,
    ComputeVirtualizedRows = ComputeVirtualizedRows
}
