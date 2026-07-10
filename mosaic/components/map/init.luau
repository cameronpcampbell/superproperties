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

type Items = {{
    Key: string,
	Value: any
}}

type MapProps = {
	Variant: ThemeUtils.BgVariantLayer?,
	Width: UDim?,
	Header: string?,
	Items: Items?
}

local function ItemsToInstances(
    scope: Fusion.Scope,
    variant: ThemeUtils.BgVariantLayer,
    header: string?,
    items: Items?,
    itemCount: number,
    mapCollapsedState: Fusion.Value<boolean>,
    tweenComputeMapSize: Fusion.Tween<UDim2>
): { Instance }?
    if not items then return nil end

    local baseIdx, instances = 0, table.create(itemCount) :: { Instance }

    if header then
        baseIdx = 1

        instances[1] = MapHeader(scope, {
            Header = header,
            Variant = variant,
            ItemCount = itemCount,
            ItemIdx = 1,
            MapCollapsedState = mapCollapsedState,
            TweenComputeMapSize = tweenComputeMapSize
        })
    end

    for idx, item in items do
        local idx = baseIdx + idx

        instances[idx] = MapItem(scope, {
            Key = item.Key,
            Value = item.Value,
            Variant = variant,
            ItemCount = itemCount,
            ItemIdx = idx
        })
    end

    return instances
end

local function CalcMapHeight(itemCount: number, lgHeight: number): number
    -- We subtract 2 to account for the stroke.
    local itemHeight = lgHeight - 2

    return itemHeight * itemCount + itemCount + 1
end

return Component<<MapProps>>(function(scope, props)
    local theme = Peek<<ThemeUtils.Theme>>(GetThemeForScope(scope))
    local lgHeight = theme:GetHeight("Lg")

    local props, variant = TableExtract(props, "Variant", "Secondary")
    local props, width = TableExtract(props, "Width", UDim.new(1, 0))
    local props, header = TableExtract(props, "Header")
    local props, items = TableExtract(props, "Items")

    local mapCollapsedState = Value(scope, false)

    local strokeVariant = GetNextVariant(variant)
    local itemCount =
        if items then if header then #items + 1 else #items else 0
    local mapUncollapsedHeight = CalcMapHeight(itemCount, lgHeight)

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

    local itemInstances =
        ItemsToInstances(
            scope, variant, header, items, itemCount,
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

        [Children] = {
            itemInstances,

            New(scope, "UIListLayout") {
                Padding = UDim.new(0, 1),
                SortOrder = Enum.SortOrder.Name
            },

            New(scope, "UIPadding") {
                PaddingLeft = UDim.new(0, 1),
                PaddingRight = UDim.new(0, 1),
                PaddingTop = UDim.new(0, 1),
                PaddingBottom = UDim.new(0, 1),
            }
        }
    }, props))
end)
