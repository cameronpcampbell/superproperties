--!strict
--!nolint LocalShadow

local Packages = script.Parent.Parent.Parent
local Supercorner = require(Packages.supercorner)

local Fusion = require(Packages.fusion)
local Peek, New, Children, Computed, Tween, ForPairs =
    Fusion.peek, Fusion.New, Fusion.Children,
    Fusion.Computed, Fusion.Tween, Fusion.ForPairs

local Utils = script.Parent.Parent.utils

local FusionUtils = require(Utils.fusionUtils)
local Component, CombineProps, CoerceToValue =
    FusionUtils.Component, FusionUtils.CombineProps,
    FusionUtils.CoerceToValue

local ThemeUtils = require(Utils.themeUtils)
local GetThemeForScope, GetNextVariant =
    ThemeUtils.GetThemeForScope, ThemeUtils.GetNextVariant

local TableUtils = require(Utils.tableUtils)
local TableExtract = TableUtils.Extract

local MapHeader = require(script.header)
local MapItem = require(script.item)
local MapEmptyItem = require(script.emptyItem)

local VirtualListHelpers = require(script.virtualListHelpers)
local CalculateMapRowCount, CalculateMapHeight, CalculateMapTopSpacerHeight,
    ComputeVirtualListVisibleRowRange, ComputeVirtualListOccludesMap =
    VirtualListHelpers.CalculateMapRowCount,
    VirtualListHelpers.CalculateMapHeight,
    VirtualListHelpers.CalculateMapTopSpacerHeight,
    VirtualListHelpers.ComputeVirtualListVisibleRowRange,
    VirtualListHelpers.ComputeVirtualListOccludesMap

type Item = {
    Key: string,
	Value: any
}

export type Items = { Item }

type RowDescriptor = Item | string

local HeaderRowDescriptor: "Header" = "Header"
local EmptyRowDescriptor: "Empty" = "Empty"

export type VirtualListData = VirtualListHelpers.VirtualListData

export type MapProps = {
	Variant: ThemeUtils.BgVariantLayer?,
	Width: UDim?,
	Header: string?,
	Items: Fusion.UsedAs<Items>?,
	HideValues: boolean?,
	EmptyText: string?,
	Collapsed: Fusion.UsedAs<boolean>?,
	VirtualListData: VirtualListData?,
}

local function ComputeRowCount(
    scope: Fusion.Scope,
    header: string?,
    items: Fusion.UsedAs<Items>?,
    emptyText: string?
)
    return Computed(scope, function(use, scope)
        local usedItems = if items then use<<Items>>(items) else nil

        return CalculateMapRowCount(
            if usedItems then #usedItems else 0,
            header ~= nil,
            emptyText ~= nil
        )
    end)
end

local function ComputeRows(
    scope: Fusion.Scope,
    variant: ThemeUtils.BgVariantLayer,
    header: string?,
    items: Fusion.UsedAs<Items>?,
    computeRowCount: Fusion.Computed<number>,
    hideValues: boolean,
    emptyText: string?,
    collapsedState: Fusion.Value<boolean>,
    tweenComputeMapSize: Fusion.Tween<UDim2>,
    visibleRowRange: Fusion.UsedAs<Vector2>?,
    lgHeight: number
): ({ Fusion.Child }, Fusion.For<number, Instance>)
    local computeVisibleRowDescriptors = Computed(scope, function(use)
        local usedRowCount = use<<number>>(computeRowCount)
        local usedItems = if items then use<<Items>>(items) else nil
        local firstRow, lastRow = 1, usedRowCount

        if visibleRowRange then
            local usedVisibleRowRange = use<<Vector2>>(visibleRowRange)
            firstRow, lastRow = usedVisibleRowRange.X, usedVisibleRowRange.Y
        end

        local descriptors = {} :: { [number]: RowDescriptor }
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
            -- Preserve the source table reference so scrolling doesn't
            -- invalidate rows that remain inside the visible range.
            descriptors[rowIdx] = usedItems[itemIdx]
        end

        return descriptors
    end)

    -- Every row has its own keyed scope. Range changes can therefore recycle
    -- only the rows that enter or leave instead of rebuilding the whole map.
    local renderedRows = ForPairs(scope, computeVisibleRowDescriptors, function(
        use,
        rowScope: Fusion.Scope,
        rowIdx: number,
        descriptor: RowDescriptor
    ): (number, Instance)
        local usedRowCount = use<<number>>(computeRowCount)

        if descriptor == HeaderRowDescriptor then
            return rowIdx, MapHeader(rowScope, {
                Header = header :: string,
                Variant = variant,
                RowCount = usedRowCount,
                RowIdx = rowIdx,
                CollapsedState = collapsedState,
                TweenComputeMapSize = tweenComputeMapSize
            })
        elseif descriptor == EmptyRowDescriptor then
            return rowIdx, MapEmptyItem(rowScope, {
                Text = emptyText :: string,
                Variant = variant,
                RowCount = usedRowCount,
                RowIdx = rowIdx,
            })
        else
            local item = descriptor :: Item

            return rowIdx, MapItem(rowScope, {
                Key = item.Key,
                Value = item.Value,
                HideValue = hideValues,
                Variant = variant,
                RowCount = usedRowCount,
                RowIdx = rowIdx
            })
        end
    end)

    local computeSkippedRowCount = Computed(scope, function(use): number
        if not visibleRowRange then return 0 end

        local usedVisibleRowRange = use<<Vector2>>(visibleRowRange)
        if usedVisibleRowRange.X > usedVisibleRowRange.Y then return 0 end

        return math.max(usedVisibleRowRange.X - 1, 0)
    end)

    local topSpacer = New(scope, "Frame") {
        Size = Computed(scope, function(use): UDim2
            local skippedRowCount = use<<number>>(computeSkippedRowCount)

            return UDim2.new(
                1, 0, 0,
                CalculateMapTopSpacerHeight(skippedRowCount, lgHeight)
            )
        end),
        BackgroundTransparency = 1,
        LayoutOrder = Computed(scope, function(use): number
            return use<<number>>(computeSkippedRowCount)
        end),
        Visible = Computed(scope, function(use): boolean
            return use<<number>>(computeSkippedRowCount) > 0
        end),

        Name = "CulledMapRowsSpacer"
    }

    return { topSpacer, renderedRows }, renderedRows
end

local function ComputeUncollapsedMapHeight(
    scope: Fusion.Scope,
    computeRowCount: Fusion.Computed<number>,
    lgHeight: number
)
    return Computed(scope, function(use, scope)
        local usedRowCount = use<<number>>(computeRowCount)

        return CalculateMapHeight(usedRowCount, lgHeight)
    end)
end

local function ComputeVisibleRows(
    scope: Fusion.Scope,
    variant: ThemeUtils.BgVariantLayer,
    header: string?,
    items: Fusion.UsedAs<Items>?,
    computeRowCount: Fusion.Computed<number>,
    hideValues: boolean,
    emptyText: string?,
    collapsedState: Fusion.Value<boolean>,
    tweenComputeMapSize: Fusion.Tween<UDim2>,
    lgHeight: number,
    visibleRowRange: Fusion.UsedAs<Vector2>?,
    virtualListOccludesMap: Fusion.UsedAs<boolean>
)
    return Computed(scope, function(
        use,
        scope: Fusion.Scope
    ): Fusion.Child?
        if use<<boolean>>(virtualListOccludesMap) then return nil end

        local rowChildren, renderedRows = ComputeRows(
            scope, variant, header, items,
            computeRowCount, hideValues, emptyText,
            collapsedState, tweenComputeMapSize,
            visibleRowRange, lgHeight
        )

        return Computed(scope, function(use): Fusion.Child?
            local usedCollapsedState = use<<boolean>>(collapsedState)
            local usedTweenComputeMapSize = use<<UDim2>>(tweenComputeMapSize)

            local isFullyCollapsed =
                usedCollapsedState and
                usedTweenComputeMapSize.Height.Offset == lgHeight

            if isFullyCollapsed then
                local usedRenderedRows =
                    use(renderedRows :: any) :: { [number]: Instance }

                return
                    if header then usedRenderedRows[1]
                    else nil

            else
                return rowChildren
            end
        end) :: any
    end)
end

return Component<<MapProps>>(function(scope, props)
    local theme = Peek<<ThemeUtils.Theme>>(GetThemeForScope(scope))
    local lgHeight = theme:GetHeight("Lg")

    local props, variant = TableExtract(props, "Variant", "Secondary")
    local props, width = TableExtract(props, "Width", UDim.new(1, 0))
    local props, header = TableExtract(props, "Header")
    local props, items = TableExtract(props, "Items")
    local props, emptyText = TableExtract(props, "EmptyText")
    local props, hideValues = TableExtract(props, "HideValues", false)
    local props, collapsed = TableExtract(props, "Collapsed", false)
    local props, virtualListData = TableExtract(props, "VirtualListData")

    local strokeVariant = GetNextVariant(variant)
    local computeRowCount = ComputeRowCount(scope, header, items, emptyText)
    local computeUncollapsedHeight =
        ComputeUncollapsedMapHeight(scope, computeRowCount, lgHeight)

    local collapsedState = CoerceToValue<<boolean>>(scope, collapsed)

    local computeVirtualListOccludesMap = ComputeVirtualListOccludesMap(
        scope, virtualListData
    )

    local computeVisibleRowRange = ComputeVirtualListVisibleRowRange(
        scope, virtualListData, computeRowCount, lgHeight
    )

    local tweenComputeMapSize = Tween<<UDim2>>(
        scope,
        Computed(scope, function(use, scope)
            local usedCollapsed = use<<boolean>>(collapsedState)
            local usedUncollapsedMapHeight =
                use<<number>>(computeUncollapsedHeight)

            local height =
                if usedCollapsed then lgHeight else usedUncollapsedMapHeight

            return UDim2.new(width, UDim.new(0, height))
        end) :: any,
        TweenInfo.new(
            .18, Enum.EasingStyle.Exponential, Enum.EasingDirection.InOut
        )
    )

    local computeVisibleRows = ComputeVisibleRows(
        scope, variant, header, items,
        computeRowCount, hideValues, emptyText,
        collapsedState, tweenComputeMapSize,
        lgHeight, computeVisibleRowRange,
        computeVirtualListOccludesMap
    )

    return Supercorner.new(scope :: any, CombineProps({
        BackgroundColor3 = theme:GetBg(scope, strokeVariant),
        StrokeColor = theme:GetBg(scope, strokeVariant),
        StrokeThickness = 1,
        Size = tweenComputeMapSize,
        ClipsDescendants = true,
        CornerRadius = theme:GetCornerRadius("Md"),
        CornerSmoothing = 1,

        Name = `Map {if header then `[{header}]` else ""}`,

        RootChildren = New(scope, "UIFlexItem") {},

        [Children] = {
            computeVisibleRows,

            New(scope, "UIListLayout") {
                Padding = UDim.new(0, 1),
                SortOrder = Enum.SortOrder.LayoutOrder
            },

            New(scope, "UIPadding") {
                PaddingLeft = UDim.new(0, 1),
                PaddingRight = UDim.new(0, 1),
                PaddingTop = UDim.new(0, 1),
                PaddingBottom = UDim.new(0, 1),
            },
        }
    }, props))
end)
