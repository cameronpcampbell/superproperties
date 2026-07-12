--!strict
--!nolint LocalShadow

local Packages = script.Parent.Parent.Parent
local Supercorner = require(Packages.supercorner)

local Fusion = require(Packages.fusion)
local Peek, New, Children, Value, Computed, Tween =
    Fusion.peek, Fusion.New, Fusion.Children,
    Fusion.Value, Fusion.Computed, Fusion.Tween

local Utils = script.Parent.Parent.utils

local FusionUtils = require(Utils.fusionUtils)
local Component, CombineProps =
    FusionUtils.Component, FusionUtils.CombineProps

local ThemeUtils = require(Utils.themeUtils)
local GetThemeForScope, GetNextVariant =
    ThemeUtils.GetThemeForScope, ThemeUtils.GetNextVariant

local TableUtils = require(Utils.tableUtils)
local TableExtract = TableUtils.Extract

local MapHeader = require(script.header)
local MapItem = require(script.item)
local MapEmptyItem = require(script.emptyItem)

type Items = {{
    Key: string,
	Value: any
}}

type MapProps = {
	Variant: ThemeUtils.BgVariantLayer?,
	Width: UDim?,
	Header: string?,
	Items: Items?,
	HideValues: boolean?,
	EmptyText: string?,
}

local function CalcRowCount(
    header: string?,
    items: Items?,
    emptyText: string?
)
    local rowCount = 0

    if items and #items ~= 0 then
        rowCount += #items

    elseif emptyText then
        rowCount += 1
    end

    if header then rowCount += 1 end

    return rowCount
end

local function ItemsToInstances(
    scope: Fusion.Scope,
    variant: ThemeUtils.BgVariantLayer,
    header: string?,
    items: Items?,
    rowCount: number,
    hideValues: boolean,
    emptyText: string?,
    mapCollapsedState: Fusion.Value<boolean>,
    tweenComputeMapSize: Fusion.Tween<UDim2>
): Fusion.Child?
    local baseIdx, instances = 0, table.create(rowCount) :: { Instance }

    if header then
        baseIdx = 1

        instances[1] = MapHeader(scope, {
            Header = header,
            Variant = variant,
            RowCount = rowCount,
            RowIdx = 1,
            MapCollapsedState = mapCollapsedState,
            TweenComputeMapSize = tweenComputeMapSize
        })
    end

    if not items or #items == 0 then
        if not emptyText then return nil end

        instances[baseIdx + 1] = MapEmptyItem(scope, {
            Text = emptyText,
            Variant = variant,
            RowCount = rowCount,
            RowIdx = baseIdx + 1,
        })

        return instances :: Fusion.Child
    end

    for idx, item in items do
        local idx = baseIdx + idx

        instances[idx] = MapItem(scope, {
            Key = item.Key,
            Value = item.Value,
            HideValue = hideValues,
            Variant = variant,
            RowCount = rowCount,
            RowIdx = idx
        })
    end

    return instances :: Fusion.Child
end

local function CalcMapHeight(rowCount: number, lgHeight: number): number
    -- We subtract 2 to account for the stroke.
    local itemHeight = lgHeight - 2

    return itemHeight * rowCount + rowCount + 1
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

    local mapCollapsedState = Value(scope, false)

    local strokeVariant = GetNextVariant(variant)
    local rowCount = CalcRowCount(header, items, emptyText)
    local mapUncollapsedHeight = CalcMapHeight(rowCount, lgHeight)

    local tweenComputeMapSize = Tween<<UDim2>>(
        scope,
        Computed(scope, function(use, scope)
            local usedMapCollapsed = use<<boolean>>(mapCollapsedState)

            local height =
                if usedMapCollapsed then lgHeight else mapUncollapsedHeight

            return UDim2.new(width, UDim.new(0, height))
        end) :: any,
        TweenInfo.new(
            .25, Enum.EasingStyle.Exponential, Enum.EasingDirection.InOut
        )
    )

    local itemInstances = ItemsToInstances(
        scope, variant, header, items,
        rowCount, hideValues, emptyText,
        mapCollapsedState, tweenComputeMapSize
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
            itemInstances,

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
