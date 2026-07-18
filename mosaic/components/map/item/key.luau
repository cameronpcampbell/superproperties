--!strict
--!nolint LocalShadow

local Packages = script.Parent.Parent.Parent.Parent.Parent
local Supercorner = require(Packages.supercorner)
local Typeforge = require(Packages.typeforge)

local Fusion = require(Packages.fusion)
local New, Children = Fusion.New, Fusion.Children

local Utils = script.Parent.Parent.Parent.Parent.utils

local FusionUtils = require(Utils.fusionUtils)
local ComputeTransforms = FusionUtils.ComputeTransforms
local ComputeUDim2, ComputeUDim =
    ComputeTransforms.UDim2, ComputeTransforms.UDim
local ComputeMath = FusionUtils.ComputeMath
local ComputeAdd = ComputeMath.Add

local ThemeUtils = require(Utils.themeUtils)
local GetThemeForScope = ThemeUtils.GetThemeForScope

local Components = script.Parent.Parent.Parent
local Text = require(Components.text)

local Assets = require(script.Parent.Parent.Parent.Parent.assets)
local Types = require(script.Parent.Parent.types)
local CalculateRowCornerRadii = require(script.Parent.Parent.cornerRadii)
local Arrow = require(script.Parent.Parent.arrow)

local IndicatorSize = 9
local IndicatorGap = 6

type MapItemKeyProps = Typeforge.Flatten<
    Types.BaseMapProps & {
        Key: string,
        Writable: boolean,
        HasSubItems: boolean,
        Nestedness: number,
        CollapsedState: Fusion.Value<boolean>?,
        Redrawable: boolean
    }
>

local function MapItemKey(scope: Fusion.Scope, props: MapItemKeyProps)
    local rowCount, rowIdx = props.RowCount, props.RowIdx
    local variant = props.Variant
    local hasSubItems: boolean = props.HasSubItems
    local nestedness: number = props.Nestedness

    local leftPadding = IndicatorGap
        + math.max(nestedness - 1, 0) * (IndicatorSize + IndicatorGap)

    local theme = GetThemeForScope(scope)
    local bgColor = theme:GetBg(scope, variant)
    local dotColor = theme:GetFg(scope, "Tertiary")
    local rowHeight = ComputeAdd(scope, theme:GetHeight(scope, "Lg"), - 2)
    local innerCornerRadius = ComputeAdd(scope, theme:GetCornerRadius(scope, "Md"), - 1)

    local indicator: Fusion.Child
    if hasSubItems then
        indicator = Arrow(scope, {
            CollapsedState = props.CollapsedState :: Fusion.Value<boolean>,
            Variant = if props.Writable then "Primary" else "Secondary"
        })

    else
        indicator = New(scope, "ImageLabel") {
            Image = Assets.Dot,
            Size = UDim2.fromOffset(IndicatorSize, IndicatorSize),
            BackgroundTransparency = 1,
            ImageColor3 = dotColor,
            ImageTransparency = .5
        }
    end

    local topLeftRadius, topRightRadius, bottomLeftRadius, bottomRightRadius =
        CalculateRowCornerRadii(
            scope,
            "Left",
            rowCount,
            rowIdx,
            props.Redrawable,
            innerCornerRadius
        )

    return Supercorner.new(scope, {
        BackgroundColor3 = bgColor,
        Size = ComputeUDim2(scope, UDim.new(1, 0), ComputeUDim(scope, 0, rowHeight)),
        TopLeftRadius = topLeftRadius,
        TopRightRadius = topRightRadius,
        BottomLeftRadius = bottomLeftRadius,
        BottomRightRadius = bottomRightRadius,
        MaxCornerRadius = if props.Redrawable then innerCornerRadius else nil,
        Redrawable = props.Redrawable,
        LayoutOrder = 0,

        Name = "MapItemKey",

        [Children] = ({
            indicator,

            Text(scope, {
                Text = props.Key,
                Variant =
                    if props.Writable then "Primary"
                    else "Secondary",
                Size = UDim2.fromScale(1, 0),

                [Children] = New(scope, "UIFlexItem") {
                    FlexMode = Enum.UIFlexMode.Shrink
                }
            }),

            New(scope, "UIListLayout") {
                Padding = UDim.new(0, IndicatorGap),
                FillDirection = Enum.FillDirection.Horizontal,
                VerticalAlignment = Enum.VerticalAlignment.Center
            },

            New(scope, "UIPadding") {
                PaddingLeft = UDim.new(0, leftPadding),
                PaddingRight = UDim.new(0, IndicatorGap)
            },
        } :: { Fusion.Child })
    })
end

return MapItemKey
