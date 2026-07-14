--!strict
--!nolint LocalShadow

local Packages = script.Parent.Parent.Parent
local Supercorner = require(Packages.supercorner)

local Fusion = require(Packages.fusion)
local Peek, New, Children, Computed, Tween =
    Fusion.peek, Fusion.New, Fusion.Children,
    Fusion.Computed, Fusion.Tween

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

export type Items = {{
    Key: string,
	Value: any
}}

export type MapProps = {
	Variant: ThemeUtils.BgVariantLayer?,
	Width: UDim?,
	Header: string?,
	Items: Fusion.UsedAs<Items>?,
	HideValues: boolean?,
	EmptyText: string?,
	Collapsed: Fusion.UsedAs<boolean>?
}

local function ComputeRowCount(
    scope: Fusion.Scope,
    header: string?,
    items: Fusion.UsedAs<Items>?,
    emptyText: string?
)
    return Computed(scope, function(use, scope)
        local usedItems = use<<{ Item }>>(items)
        local rowCount = 0

        if usedItems and #usedItems ~= 0 then
            rowCount += #usedItems

        elseif emptyText then
            rowCount += 1
        end

        if header then rowCount += 1 end

        return rowCount
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
    tweenComputeMapSize: Fusion.Tween<UDim2>
): Fusion.Computed<{ Fusion.Child }?>
    return Computed(scope, function(use, scope: Fusion.Scope): { Fusion.Child }?
        local usedRowCount = use<<number>>(computeRowCount)
        local usedItems = use<<{ Item }>>(items)
        local baseIdx, instances = 0, table.create(usedRowCount) :: { Instance }

        if header then
            baseIdx = 1

            instances[1] = MapHeader(scope, {
                Header = header,
                Variant = variant,
                RowCount = usedRowCount,
                RowIdx = 1,
                CollapsedState = collapsedState,
                TweenComputeMapSize = tweenComputeMapSize
            })
        end

        if not usedItems or #usedItems == 0 then
            if not emptyText then return instances :: { Fusion.Child } end

            instances[baseIdx + 1] = MapEmptyItem(scope, {
                Text = emptyText,
                Variant = variant,
                RowCount = usedRowCount,
                RowIdx = baseIdx + 1,
            })

            return instances :: { Fusion.Child }
        end

        for idx, item in usedItems do
            local idx = baseIdx + idx

            instances[idx] = MapItem(scope, {
                Key = item.Key,
                Value = item.Value,
                HideValue = hideValues,
                Variant = variant,
                RowCount = usedRowCount,
                RowIdx = idx
            })
        end

        return instances :: { Fusion.Child }
    end)
end

local function ComputeUncollapsedMapHeight(
    scope: Fusion.Scope,
    computeRowCount: Fusion.Computed<number>,
    lgHeight: number
)
    return Computed(scope, function(use, scope)
        local usedRowCount = use<<number>>(computeRowCount)

        -- We subtract 2 to account for the stroke.
        local itemHeight = lgHeight - 2

        return itemHeight * usedRowCount + usedRowCount + 1
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

    local strokeVariant = GetNextVariant(variant)
    local computeRowCount = ComputeRowCount(scope, header, items, emptyText)
    local computeUncollapsedHeight =
        ComputeUncollapsedMapHeight(scope, computeRowCount, lgHeight)

    local collapsedState = CoerceToValue<<boolean>>(scope, collapsed)

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

    local computeRows = ComputeRows(
        scope, variant, header, items,
        computeRowCount, hideValues, emptyText,
        collapsedState, tweenComputeMapSize
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
            Computed(scope, function(use, scope): Fusion.Child?
                local usedTweenComputeMapSize = use(tweenComputeMapSize)
                local usedComputeRows = use(computeRows :: any) :: { Fusion.Child }?

                if usedTweenComputeMapSize.Height.Offset == lgHeight then
                    return
                        if header then (usedComputeRows :: { Fusion.Child })[1]
                        else nil

                else
                    return usedComputeRows :: any
                end
            end),

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
