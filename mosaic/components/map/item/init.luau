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
        Value: any
    }
>

local function MapItem(scope: Fusion.Scope, props: MapItemProps)
    local theme = Peek<<ThemeUtils.Theme>>(GetThemeForScope(scope))

    local rowCount, rowIdx = props.RowCount, props.RowIdx
    local variant = props.Variant
    local key, value = props.Key, props.Value

    return New(scope, "Frame") {
        BackgroundTransparency = 1,
        -- We subtract 2 to account for the for the extra stroke that will be added.
        Size = UDim2.new(1, 0, 0, theme:GetHeight("Lg") - 2),
        LayoutOrder = props.RowIdx,

        Name = `MapItem [{key}]`,

        [Children] = {
            MapItemKey(scope, {
                Key = key,
                Variant = variant,
                RowCount = rowCount,
                RowIdx = rowIdx,
            }),

            MapItemValue(scope, {
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
