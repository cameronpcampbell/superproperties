--!strict
--!nolint LocalShadow

local Packages = script.Parent.Parent.Parent.Parent.Parent
local Supercorner = require(Packages.supercorner)
local Typeforge = require(Packages.typeforge)

local Fusion = require(Packages.fusion)
local Peek, New, Children = Fusion.peek, Fusion.New, Fusion.Children

local Utils = script.Parent.Parent.Parent.Parent.utils

local ThemeUtils = require(Utils.themeUtils)
local GetThemeForScope = ThemeUtils.GetThemeForScope

local Components = script.Parent.Parent.Parent
local Text = require(Components.text)

local Assets = require(script.Parent.Parent.Parent.Parent.assets)
local Types = require(script.Parent.Parent.types)

type MapItemKeyProps = Typeforge.Flatten<
    Types.BaseMapProps & {
        Key: string
    }
>

local function CalcKeyCornerRadii(
    itemCount: number,
    itemIdx: number,
    baseRadius: number
): (number, number, number, number)
    local topLeftRadius = 0
    local bottomLeftRadius = 0

    if itemIdx == 1 then
        topLeftRadius = baseRadius
    end

    if itemIdx == itemCount then
        bottomLeftRadius = baseRadius
    end

    return topLeftRadius, 0, bottomLeftRadius, 0
end

local function MapItemKey(scope: Fusion.Scope, props: MapItemKeyProps)
    local theme = Peek<<ThemeUtils.Theme>>(GetThemeForScope(scope))

    local itemCount, itemIdx = props.ItemCount, props.ItemIdx
    local variant = props.Variant

    local topLeftRadius, topRightRadius, bottomLeftRadius, bottomRightRadius =
        -- We subtract 1 as we this squircle is inset by 1px.
        CalcKeyCornerRadii(itemCount, itemIdx, theme:GetCornerRadius("Md") - 1)

    return Supercorner.new(scope, {
        BackgroundColor3 = theme:GetBg(scope, variant),
        Size = UDim2.fromScale(1, 1),
        TopLeftRadius = topLeftRadius,
        TopRightRadius = topRightRadius,
        BottomLeftRadius = bottomLeftRadius,
        BottomRightRadius = bottomRightRadius,
        LayoutOrder = 0,

        Name = "MapItemKey",

        [Children] = {
            New(scope, "ImageLabel") {
                Image = Assets.Dot,
                Size = UDim2.fromOffset(9, 9),
                BackgroundTransparency = 1,
                ImageColor3 = theme:GetFg(scope, "Tertiary"),
                ImageTransparency = .5
            },

            Text(scope, {
                Text = props.Key,
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

return MapItemKey
