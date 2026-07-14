--!strict
--!nolint LocalShadow

local Packages = script.Parent.Parent.Parent.Parent
local Supercorner = require(Packages.supercorner)
local Typeforge = require(Packages.typeforge)

local Fusion = require(Packages.fusion)
local Peek, New, Children = Fusion.peek, Fusion.New, Fusion.Children

local Utils = script.Parent.Parent.Parent.utils

local ThemeUtils = require(Utils.themeUtils)
local GetThemeForScope = ThemeUtils.GetThemeForScope

local Components = script.Parent.Parent
local Text = require(Components.text)

local Assets = require(script.Parent.Parent.Parent.assets)
local Types = require(script.Parent.types)

type MapEmptyItemProps = Typeforge.Flatten<
    Types.BaseMapProps & {
        Text: string
    }
>

local function CalcKeyCornerRadii(
    rowCount: number,
    rowIdx: number,
    baseRadius: number
): (number, number, number, number)
    local topLeftRadius = 0
    local bottomLeftRadius = 0

    if rowIdx == 1 then
        topLeftRadius = baseRadius
    end

    if rowIdx == rowCount then
        bottomLeftRadius = baseRadius
    end

    return topLeftRadius, 0, bottomLeftRadius, 0
end

local function MapEmptyItem(scope: Fusion.Scope, props: MapEmptyItemProps)
    local theme = Peek<<ThemeUtils.Theme>>(GetThemeForScope(scope))

    local rowCount, rowIdx = props.RowCount, props.RowIdx
    local variant = props.Variant

    local topLeftRadius, topRightRadius, bottomLeftRadius, bottomRightRadius =
        -- We subtract 1 as we this squircle is inset by 1px.
        CalcKeyCornerRadii(rowCount, rowIdx, theme:GetCornerRadius("Md") - 1)

    return Supercorner.new(scope, {
        BackgroundColor3 = theme:GetBg(scope, variant),
        -- We subtract 2 to account for the for the extra stroke that will be added.
        Size = UDim2.new(1, 0, 0, theme:GetHeight("Lg") - 2),
        TopLeftRadius = topLeftRadius,
        TopRightRadius = topRightRadius,
        BottomLeftRadius = bottomLeftRadius,
        BottomRightRadius = bottomRightRadius,
        LayoutOrder = props.RowIdx,

        Name = "MapItem",

        [Children] = {
            New(scope, "ImageLabel") {
                Image = Assets.Dot,
                Size = UDim2.fromOffset(9, 9),
                BackgroundTransparency = 1,
                ImageColor3 = theme:GetFg(scope, "Tertiary"),
                ImageTransparency = .5
            },

            Text(scope, {
                Text = props.Text,
                Variant = "Secondary",
                Size = UDim2.fromScale(1, 0),

                [Children] = New(scope, "UIFlexItem") {
                    FlexMode = Enum.UIFlexMode.Shrink
                }
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

return MapEmptyItem
