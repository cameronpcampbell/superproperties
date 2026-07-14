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
local CalculateRowCornerRadii = require(script.Parent.Parent.cornerRadii)
local Arrow = require(script.Parent.Parent.arrow)

local IndicatorSize = 9
local IndicatorGap = 6

type MapItemKeyProps = Typeforge.Flatten<
    Types.BaseMapProps & {
        Key: string,
        HasSubItems: boolean,
        Nestedness: number,
        CollapsedState: Fusion.Value<boolean>?,
        Redrawable: boolean
    }
>

local function MapItemKey(scope: Fusion.Scope, props: MapItemKeyProps)
    local theme = Peek<<ThemeUtils.Theme>>(GetThemeForScope(scope))
    local rowHeight = theme:GetHeight("Lg") - 2
    local innerCornerRadius = theme:GetCornerRadius("Md") - 1

    local rowCount, rowIdx = props.RowCount, props.RowIdx
    local variant = props.Variant
    local hasSubItems: boolean = props.HasSubItems
    local nestedness: number = props.Nestedness

    local leftPadding = IndicatorGap
        + math.max(nestedness - 1, 0) * (IndicatorSize + IndicatorGap)

    local indicator: Fusion.Child
    if hasSubItems then
        indicator = Arrow(scope, {
            CollapsedState = props.CollapsedState :: Fusion.Value<boolean>
        })
    else
        indicator = New(scope, "ImageLabel") {
            Image = Assets.Dot,
            Size = UDim2.fromOffset(IndicatorSize, IndicatorSize),
            BackgroundTransparency = 1,
            ImageColor3 = theme:GetFg(scope, "Tertiary"),
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
        BackgroundColor3 = theme:GetBg(scope, variant),
        Size = UDim2.new(1, 0, 0, rowHeight),
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
