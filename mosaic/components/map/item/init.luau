--!strict
--!nolint LocalShadow

local Packages = script.Parent.Parent.Parent.Parent
local Typeforge = require(Packages.typeforge)

local Fusion = require(Packages.fusion)
local Peek, New, Children = Fusion.peek, Fusion.New, Fusion.Children

local Utils = script.Parent.Parent.Parent.utils

local ThemeUtils = require(Utils.themeUtils)
local GetThemeForScope = ThemeUtils.GetThemeForScope

local Types = require(script.Parent.types)
local MapItemKey = require(script.key)
local MapItemValue = require(script.value)

type MapItemProps = Typeforge.Flatten<
    Types.BaseMapProps & {
        Key: string,
        Value: any,
        HideValue: boolean?,
        SubItems: Types.Items?,
        Nestedness: number
    }
>

local function MapItem(scope: Fusion.Scope, props: MapItemProps)
    local theme = Peek<<ThemeUtils.Theme>>(GetThemeForScope(scope))
    local rowHeight = theme:GetHeight("Lg") - 2

    local rowCount, rowIdx = props.RowCount, props.RowIdx
    local variant = props.Variant
    local key, value, hideValue = props.Key, props.Value, props.HideValue
    local subItems = props.SubItems
    local nestedness = props.Nestedness

    return New(scope, "Frame") {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, rowHeight),
        LayoutOrder = props.RowIdx,

        Name = `MapItem [{key}]`,

        [Children] = {
            MapItemKey(scope, {
                Key = key,
                Variant = variant,
                RowCount = rowCount,
                RowIdx = rowIdx,
                HasSubItems = if subItems and #subItems ~= 0 then true else false,
                Nestedness = nestedness
            }),

            if hideValue then nil else MapItemValue(scope, {
                Value = value,
                Variant = variant,
                RowCount = rowCount,
                RowIdx = rowIdx,
            }),

            New(scope, "UIListLayout") {
                Padding = UDim.new(0, 1),
                FillDirection = Enum.FillDirection.Horizontal,
                HorizontalFlex = Enum.UIFlexAlignment.Fill,
                SortOrder = Enum.SortOrder.LayoutOrder
            },
        }
    }
end

return MapItem
