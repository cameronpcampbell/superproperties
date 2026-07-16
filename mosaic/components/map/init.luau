--!strict
--!nolint LocalShadow

local Packages = script.Parent.Parent.Parent
local Supercorner = require(Packages.supercorner)

local Fusion = require(Packages.fusion)
local New, Children, Computed, Peek =
    Fusion.New, Fusion.Children, Fusion.Computed, Fusion.peek

local Utils = script.Parent.Parent.utils

local FusionUtils = require(Utils.fusionUtils)
local Component, CombineProps, CoerceToValue =
    FusionUtils.Component, FusionUtils.CombineProps,
    FusionUtils.CoerceToValue
local ComputeMath = FusionUtils.ComputeMath
local ComputeAdd = ComputeMath.Add

local ThemeUtils = require(Utils.themeUtils)
local GetThemeForScope, GetNextVariant =
    ThemeUtils.GetThemeForScope, ThemeUtils.GetNextVariant

local TableUtils = require(Utils.tableUtils)
local TableExtract = TableUtils.Extract

local Types = require(script.types)

local Virtualization = require(script.virtualization)
local CreateMapLayout, CreateMapSizeTween,
    ComputeVirtualListVisibleRootRange, ComputeVirtualizedRows =
    Virtualization.CreateMapLayout,
    Virtualization.CreateMapSizeTween,
    Virtualization.ComputeVirtualListVisibleRootRange,
    Virtualization.ComputeVirtualizedRows

export type Item = Types.Item
export type Items = Types.Items
export type VirtualListData = Virtualization.VirtualListData

export type MapProps = {
    Variant: ThemeUtils.BgVariantLayer?,
    Width: UDim?,
    Header: string?,
    HeaderChildren: { Fusion.Child }?,
    Items: Fusion.UsedAs<Items>?,
    HideValues: boolean?,
    EmptyText: string?,
    Collapsed: Fusion.UsedAs<boolean>?,
    VirtualListData: VirtualListData?,
}

return Component<<MapProps>>(function(scope, props)
    -- TypeError: Code is too complex to typecheck!
    local props: MapProps, variant = (TableExtract :: any)(props, "Variant", "Secondary")
    local props: MapProps, width = (TableExtract :: any)(props, "Width", UDim.new(1, 0))
    local props: MapProps, header = (TableExtract :: any)(props, "Header")
    local props, headerChildren = TableExtract(props, "HeaderChildren")
    local props, items = TableExtract(props, "Items")
    local props, emptyText = TableExtract(props, "EmptyText")
    local props, hideValues = TableExtract(props, "HideValues", false)
    local props, collapsed = TableExtract(props, "Collapsed", false)
    local props, virtualListData = TableExtract(props, "VirtualListData")

    local strokeVariant = GetNextVariant(variant)
    local collapsedState = CoerceToValue<<boolean>>(scope, collapsed)

    local theme = GetThemeForScope(scope)
    local strokeColor = theme:GetBg(scope, strokeVariant)
    local height = theme:GetHeight(scope, "Lg")
    local cornerRadius = theme:GetCornerRadius(scope, "Md")

    local rowHeight = ComputeAdd(scope, height, - 2)

    local layout =
        if virtualListData then virtualListData.Layout
        else CreateMapLayout(scope, header, items, emptyText, rowHeight)

    local visibleRootRange = ComputeVirtualListVisibleRootRange(
        scope,
        virtualListData,
        layout,
        rowHeight
    )

    -- The parent supplies these states so unmounted maps continue animating.
    local animatedMapSize: Fusion.UsedAs<UDim2>
    local mapReveal: Fusion.UsedAs<number>

    if virtualListData
        and virtualListData.AnimatedMapSize
        and virtualListData.MapReveal
    then
        animatedMapSize = virtualListData.AnimatedMapSize
        mapReveal = virtualListData.MapReveal
    else
        animatedMapSize, mapReveal = CreateMapSizeTween(
            scope,
            width,
            collapsedState,
            layout.AnimatedExpandedHeight,
            height
        )
    end

    -- Drive clipping from the reveal so reactive height targets cannot toggle
    -- it mid-animation. Stable bounds stay open for value focus rings.
    local clipsDescendants = Computed(scope, function(use): boolean
        local reveal = use<<number>>(mapReveal)
        return reveal > 0 and reveal < 1
    end)

    local visibleRows = ComputeVirtualizedRows(scope, {
        Variant = variant,
        Header = header,
        HeaderChildren = headerChildren,
        HideValues = hideValues,
        EmptyText = emptyText,
        Layout = layout,
        CollapsedState = collapsedState,
        AnimatedMapSize = animatedMapSize,
        VisibleRootRange = visibleRootRange,
        RowHeight = height
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
        BackgroundColor3 = strokeColor,
        Size = animatedMapSize,
        ClipsDescendants = clipsDescendants,
        CornerRadius = Peek<<number>>(cornerRadius),
        CornerSmoothing = 1,

        Name = `Map {if header then `[{header}]` else ""}`,

        RootChildren = New(scope, "UIFlexItem") {},

        [Children] = mapChildren
    }, props :: any))
end)
