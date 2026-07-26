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
local CreateHeaderColors = require(script.header.createHeaderColors)

local Virtualization = require(script.virtualization)
local CreateMapLayout, CreateMapSizeTween,
    ComputeVirtualListVisibleRootRange, ComputeVirtualizedRows =
    Virtualization.CreateMapLayout,
    Virtualization.CreateMapSizeTween,
    Virtualization.ComputeVirtualListVisibleRootRange,
    Virtualization.ComputeVirtualizedRows
local ZIndices = require(script.zIndices)

local StrokeInset = 1
local VerticalStrokeInset = StrokeInset * 2

export type Item = Types.Item
export type Items = Types.Items
export type TransformValue = Types.TransformValue
export type TryTransformValue = Types.TryTransformValue
export type ValueVariantProps<T> = Types.ValueVariantProps<T>
export type ValueVariantFn<T> = Types.ValueVariantFn<T>
export type ValueType = Types.ValueType
export type HeaderColors = Types.HeaderColors
export type HeaderChildrenBuilder = Types.HeaderChildrenBuilder
export type HeaderChildren = Types.HeaderChildren
export type VirtualListData = Virtualization.VirtualListData

export type MapProps = {
    Variant: ThemeUtils.BgVariantLayer?,
    Width: UDim?,
    Header: string?,
    PreviousHeader: string?,
    HeaderColorTint: Fusion.UsedAs<boolean>?,
    HeaderChildren: HeaderChildren?,
    HeaderOverlay: Fusion.Child?,
    ShowOnTop: Fusion.UsedAs<boolean>?,
    Items: Fusion.UsedAs<Items>?,
    EmptyText: string?,
    Collapsible: boolean?,
    Collapsed: Fusion.UsedAs<boolean>?,
    VirtualListData: VirtualListData?,
}

type MapComponent = (Fusion.Scope, MapProps, ...any) -> Fusion.Child

local MapComponent = (Component :: any)(function(
    scope: Fusion.Scope,
    props: MapProps
): Fusion.Child
    -- TypeError: Code is too complex to typecheck!
    local props: MapProps, variant = (TableExtract :: any)(props, "Variant", "Secondary")
    local props: MapProps, width = (TableExtract :: any)(props, "Width", UDim.new(1, 0))
    local props: MapProps, header = (TableExtract :: any)(props, "Header")
    local props: MapProps, previousHeader =
        (TableExtract :: any)(props, "PreviousHeader")
    local props: MapProps, headerColorTint =
        (TableExtract :: any)(props, "HeaderColorTint", false)
    local props: MapProps, headerChildren = (TableExtract :: any)(props, "HeaderChildren")
    local props: MapProps, headerOverlay = (TableExtract :: any)(props, "HeaderOverlay")
    local props: MapProps, showOnTop = (TableExtract :: any)(props, "ShowOnTop", false)
    local props: MapProps, items = (TableExtract :: any)(props, "Items")
    local props: MapProps, emptyText = (TableExtract :: any)(props, "EmptyText")
    local props: MapProps, collapsible =
        (TableExtract :: any)(props, "Collapsible", true)
    local props: MapProps, collapsed = (TableExtract :: any)(props, "Collapsed", false)
    local props: MapProps, virtualListData = (TableExtract :: any)(props, "VirtualListData")

    local strokeVariant = GetNextVariant(scope, variant)
    local collapsedState = CoerceToValue<<boolean>>(
        scope,
        if collapsible then collapsed else false
    )

    local theme = GetThemeForScope(scope)
    local strokeColor = theme:GetBg(scope, strokeVariant)
    local height = theme:GetHeight(scope, "Lg")
    local cornerRadius = theme:GetCornerRadius(scope, "Md")

    local headerColors: HeaderColors? =
        if header
        then CreateHeaderColors(scope, {
            Header = header,
            PreviousHeader = previousHeader,
            HeaderColorTint = headerColorTint,
            BackgroundBaseColor3 =
                theme:GetBgHighlight(scope, variant),
            ForegroundBaseColor3 =
                theme:GetFg(scope, "Primary")
        })
        else nil
    local resolvedHeaderChildren: { Fusion.Child }? = nil

    if type(headerChildren) == "function" then
        if headerColors then
            resolvedHeaderChildren = (
                headerChildren :: HeaderChildrenBuilder
            )(scope, headerColors)
        end
    else
        resolvedHeaderChildren =
            headerChildren :: { Fusion.Child }?
    end

    local rowHeight = ComputeAdd(scope, height, - VerticalStrokeInset)

    local layout =
        if virtualListData then virtualListData.Layout
        else CreateMapLayout(scope, header, items, emptyText, rowHeight)

    local visibleRootRange = ComputeVirtualListVisibleRootRange(
        scope,
        virtualListData,
        layout
    )

    -- The parent supplies these states so unmounted maps continue animating.
    local animatedMapSize: Fusion.UsedAs<UDim2>
    local mapReveal: Fusion.UsedAs<number>

    if virtualListData
        and virtualListData.AnimatedMapSize
        and virtualListData.MapReveal
    then
        animatedMapSize = virtualListData.AnimatedMapSize :: any
        mapReveal = virtualListData.MapReveal :: any
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

    local animatedContentSize = Computed(
        scope,
        function(use: Fusion.Use): UDim2
            local mapSize = use<<UDim2>>(animatedMapSize)

            return UDim2.new(
                UDim.new(1, 0),
                UDim.new(
                    mapSize.Height.Scale,
                    mapSize.Height.Offset - VerticalStrokeInset
                )
            )
        end
    )

    local headerZIndex = Computed(scope, function(use: Fusion.Use): number
        return
            if use<<boolean>>(showOnTop) then ZIndices.Focus
            else ZIndices.Default
    end)

    local visibleRows = ComputeVirtualizedRows(scope, {
        Variant = variant,
        Header = header,
        HeaderColors = headerColors,
        HeaderChildren = resolvedHeaderChildren,
        HeaderOverlay = headerOverlay,
        HeaderZIndex = headerZIndex,
        ShowOnTop = showOnTop,
        EmptyText = emptyText,
        Layout = layout,
        Collapsible = collapsible,
        CollapsedState = collapsedState,
        AnimatedMapSize = animatedMapSize,
        VisibleRootRange = visibleRootRange,
        RowHeight = height
    })

    local mapZIndex = Computed(scope, function(use: Fusion.Use): number
        local focusedRootRange =
            use<<Vector2>>(layout.FocusedRootRange)
        local hasFocusedRow = focusedRootRange.X <= focusedRootRange.Y

        return
            if hasFocusedRow or use<<boolean>>(showOnTop) then ZIndices.Focus
            else ZIndices.Default
    end)

    local mapContent = New(scope, "Frame") {
        BackgroundTransparency = 1,
        Size = animatedContentSize,
        ClipsDescendants = clipsDescendants,

        Name = "MapContent",

        [Children] = ({
            visibleRows,

            New(scope, "UIListLayout") {
                Padding = UDim.new(0, 1),
                SortOrder = Enum.SortOrder.LayoutOrder
            }
        } :: { Fusion.Child })
    }

    return Supercorner.new(scope, CombineProps({
        BackgroundColor3 = strokeColor,
        Size = animatedMapSize,
        ZIndex = mapZIndex,
        CornerRadius = Peek<<number>>(cornerRadius),
        CornerSmoothing = 1,

        Name = `Map {if header then `[{header}]` else ""}`,

        RootChildren = New(scope, "UIFlexItem") {},

        [Children] = {
            mapContent,

            New(scope, "UIPadding") {
                PaddingLeft = UDim.new(0, StrokeInset),
                PaddingRight = UDim.new(0, StrokeInset),
                PaddingTop = UDim.new(0, StrokeInset),
                PaddingBottom = UDim.new(0, StrokeInset)
            }
        }
    }, props :: any))
end) :: MapComponent

return MapComponent
