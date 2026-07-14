--!strict
--!nolint LocalShadow

local Packages = script.Parent.Parent.Parent
local Supercorner = require(Packages.supercorner)

local Fusion = require(Packages.fusion)
local Peek, New, Children = Fusion.peek, Fusion.New, Fusion.Children

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

local Virtualization = require(script.virtualization)
local ComputeMapRowCount, CreateMapSizeTween,
    ComputeVirtualListVisibleRowRange, ComputeVirtualizedRows =
    Virtualization.ComputeMapRowCount,
    Virtualization.CreateMapSizeTween,
    Virtualization.ComputeVirtualListVisibleRowRange,
    Virtualization.ComputeVirtualizedRows

export type Item = Virtualization.Item
export type Items = Virtualization.Items
export type VirtualListData = Virtualization.VirtualListData

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

    local strokeVariant: ThemeUtils.BgVariant = GetNextVariant(variant)
    local collapsedState = CoerceToValue<<boolean>>(scope, collapsed)
    local rowCount =
        if virtualListData and virtualListData.RowCount
        then virtualListData.RowCount
        else ComputeMapRowCount(scope, header, items, emptyText)

    local visibleRowRange = ComputeVirtualListVisibleRowRange(
        scope,
        virtualListData,
        rowCount,
        lgHeight
    )

    -- The parent supplies this tween so unmounted maps continue animating.
    local animatedMapSize =
        if virtualListData and virtualListData.AnimatedMapSize
        then virtualListData.AnimatedMapSize
        else CreateMapSizeTween(
            scope,
            width,
            collapsedState,
            rowCount,
            lgHeight
        )

    local visibleRows = ComputeVirtualizedRows(scope, {
        Variant = variant,
        Header = header,
        Items = items,
        HideValues = hideValues,
        EmptyText = emptyText,
        RowCount = rowCount,
        CollapsedState = collapsedState,
        AnimatedMapSize = animatedMapSize,
        VisibleRowRange = visibleRowRange,
        RowHeight = lgHeight
    })

    local mapChildren: { Fusion.Child } = {
        visibleRows,

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

    return Supercorner.new(scope, CombineProps({
        BackgroundColor3 = theme:GetBg(scope, strokeVariant, nil),
        StrokeColor = theme:GetBg(scope, strokeVariant, nil),
        StrokeThickness = 1,
        Size = animatedMapSize,
        ClipsDescendants = true,
        CornerRadius = theme:GetCornerRadius("Md"),
        CornerSmoothing = 1,

        Name = `Map {if header then `[{header}]` else ""}`,

        RootChildren = New(scope, "UIFlexItem") {},

        [Children] = mapChildren
    }, props))
end)
