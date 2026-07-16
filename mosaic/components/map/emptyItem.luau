--!strict
--!nolint LocalShadow

local Packages = script.Parent.Parent.Parent.Parent
local Supercorner = require(Packages.supercorner)
local Typeforge = require(Packages.typeforge)

local Fusion = require(Packages.fusion)
local New, Children = Fusion.New, Fusion.Children

local Utils = script.Parent.Parent.Parent.utils

local FusionUtils = require(Utils.fusionUtils)
local ComputeTransforms = FusionUtils.ComputeTransforms
local ComputeUDim2, ComputeUDim =
    ComputeTransforms.UDim2, ComputeTransforms.UDim
local ComputeMath = FusionUtils.ComputeMath
local ComputeAdd = ComputeMath.Add

local ThemeUtils = require(Utils.themeUtils)
local GetThemeForScope = ThemeUtils.GetThemeForScope

local Components = script.Parent.Parent
local Text = require(Components.text)

local Assets = require(script.Parent.Parent.Parent.assets)
local Types = require(script.Parent.types)
local CalculateRowCornerRadii = require(script.Parent.cornerRadii)

type MapEmptyItemProps = Typeforge.Flatten<
    Types.BaseMapProps & {
        Text: string
    }
>

local function MapEmptyItem(scope: Fusion.Scope, props: MapEmptyItemProps)
    local rowCount, rowIdx = props.RowCount, props.RowIdx
    local variant = props.Variant

    local theme = GetThemeForScope(scope)
    local bgColor = theme:GetBg(scope, variant)
    local dotColor = theme:GetFg(scope, "Tertiary")
    local rowHeight = ComputeAdd(scope, theme:GetHeight(scope, "Lg"), - 2)
    local innerCornerRadius = ComputeAdd(scope, theme:GetCornerRadius(scope, "Md"), - 1)

    local topLeftRadius, topRightRadius, bottomLeftRadius, bottomRightRadius =
        CalculateRowCornerRadii(
            scope,
            "Both",
            rowCount,
            rowIdx,
            true,
            innerCornerRadius
        )

    return Supercorner.new(scope, {
        BackgroundColor3 = bgColor,
        Size = ComputeUDim2(scope, UDim.new(1, 0), ComputeUDim(scope, 0, rowHeight)),
        TopLeftRadius = topLeftRadius,
        TopRightRadius = topRightRadius,
        BottomLeftRadius = bottomLeftRadius,
        BottomRightRadius = bottomRightRadius,
        MaxCornerRadius = innerCornerRadius,
        Redrawable = true,
        LayoutOrder = rowIdx,

        Name = "MapEmptyItem",

        [Children] = ({
            New(scope, "ImageLabel") {
                Image = Assets.Dot,
                Size = UDim2.fromOffset(9, 9),
                BackgroundTransparency = 1,
                ImageColor3 = dotColor,
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
        } :: { Fusion.Child })
    })
end

return MapEmptyItem
