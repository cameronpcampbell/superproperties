--!strict
--!nolint LocalShadow

local Packages = script.Parent.Parent.Parent.Parent.Parent.packages
local Supercorner = require(Packages.supercorner)
local Typeforge = require(Packages.typeforge)

local Fusion = require(Packages.fusion)
local Peek, New, Children = Fusion.peek, Fusion.New, Fusion.Children

local Utils = script.Parent.Parent.Parent.Parent.utils

local ThemeUtils = require(Utils.themeUtils)
local GetThemeForScope = ThemeUtils.GetThemeForScope

local Components = script.Parent.Parent.Parent
local Text = require(Components.text)
local Checkbox = require(Components.checkbox)

local Types = require(script.Parent.Parent.types)

type MapItemValueProps = Typeforge.Flatten<
    Types.BaseMapProps & {
        Value: any
    }
>

local function CalcValueCornerRadii(
    itemCount: number,
    itemIdx: number,
    baseRadius: number
): (number, number, number, number)
    local topRightRadius = 0
    local bottomRightRadius = 0

    if itemIdx == 1 then
        topRightRadius = baseRadius
    end

    if itemIdx == itemCount then
        bottomRightRadius = baseRadius
    end

    return 0, topRightRadius, 0, bottomRightRadius
end

local function MapItemValue(scope: Fusion.Scope, props: MapItemValueProps)
    local theme = Peek<<ThemeUtils.Theme>>(GetThemeForScope(scope))

    local itemCount, itemIdx = props.ItemCount, props.ItemIdx
    local variant = props.Variant

    local topLeftRadius, topRightRadius, bottomLeftRadius, bottomRightRadius =
        -- We subtract 1 as we this squircle is inset by 1px.
        CalcValueCornerRadii(itemCount, itemIdx, theme:GetCornerRadius("Md") - 1)

    return Supercorner.new(scope, {
        BackgroundColor3 = theme:GetBg(scope, variant),
        Size = UDim2.fromScale(1, 1),
        TopLeftRadius = topLeftRadius,
        TopRightRadius = topRightRadius,
        BottomLeftRadius = bottomLeftRadius,
        BottomRightRadius = bottomRightRadius,
        LayoutOrder = 1,

        Name = "MapItemValue",

        [Children] = {
            if type(props.Value) == "boolean" then
                Checkbox(scope, {
                    Checked = props.Value
                })
            else
                Text(scope, {
                    Text = tostring(props.Value),
                    TextColor = "Primary",
                    FontWeight = Enum.FontWeight.Regular
                }),

            New(scope, "UIListLayout") {
                Padding = UDim.new(0, 6),
                FillDirection = Enum.FillDirection.Horizontal,
                VerticalAlignment = Enum.VerticalAlignment.Center
            },

            New(scope, "UIPadding") {
                PaddingLeft = UDim.new(0, 6),
                PaddingRight = UDim.new(0, 6)
            }
        }
    })
end

return MapItemValue
