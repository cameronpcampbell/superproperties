--!strict
--!nolint LocalShadow

local Packages = script.Parent.Parent.Parent.Parent.packages
local Fusion = require(Packages.fusion)
local Typeforge = require(Packages.typeforge)

local Utils = script.Parent.Parent.Parent.utils
local ThemeUtils = require(Utils.themeUtils)

local Types = require(script.Parent.types)
local MapItemKey = require(script.key)
local MapItemValue = require(script.value)

local Peek, New, Children = Fusion.peek, Fusion.New, Fusion.Children
local GetThemeForScope = ThemeUtils.GetThemeForScope

type MapItemProps = Typeforge.Flatten<
    Types.BaseMapProps & {
        Key: string,
        Value: any
    }
>

local function MapItem(scope: Fusion.Scope, props: MapItemProps)
    local theme = Peek<<ThemeUtils.Theme>>(GetThemeForScope(scope))

    local itemCount, itemIdx = props.ItemCount, props.ItemIdx
    local variant = props.Variant
    local key, value = props.Key, props.Value

    return New(scope, "Frame") {
        BackgroundTransparency = 1,
        -- We subtract 2 to account for the for the extra stroke that will be added.
        Size = UDim2.new(1, 0, 0, theme:GetHeight("Lg") - 2),
        LayoutOrder = props.ItemIdx,

        Name = `MapItem [{key}]`,

        [Children] = {
            MapItemKey(scope, {
                Key = key,
                Variant = variant,
                ItemCount = itemCount,
                ItemIdx = itemIdx,
            }),

            MapItemValue(scope, {
                Value = value,
                Variant = variant,
                ItemCount = itemCount,
                ItemIdx = itemIdx,
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
