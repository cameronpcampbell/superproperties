--!strict
--!nolint LocalShadow

local Packages = script.Parent.Parent.Parent.Parent
local Supercorner = require(Packages.supercorner)
local Typeforge = require(Packages.typeforge)

local Fusion = require(Packages.fusion)
local Peek, New, Children, Computed =
    Fusion.peek, Fusion.New, Fusion.Children, Fusion.Computed

local Utils = script.Parent.Parent.Parent.utils

local ThemeUtils = require(Utils.themeUtils)
local GetThemeForScope = ThemeUtils.GetThemeForScope

local Components = script.Parent.Parent
local Text = require(Components.text)

local Types = require(script.Parent.types)
local Arrow = require(script.Parent.arrow)

type MapHeaderProps = Typeforge.Flatten<
    Types.BaseMapProps & {
        Header: string,
        CollapsedState: Fusion.Value<boolean>,
        TweenComputeMapSize: Fusion.UsedAs<UDim2>
    }
>

local function ComputeCornerRadii(
    scope: Fusion.Scope,
    rowCount: Fusion.UsedAs<number>,
    rowIdx: Fusion.UsedAs<number>,
    baseRadius: number,
    tweenComputeMapSize: Fusion.UsedAs<UDim2>
): (
    Fusion.Computed<number>, Fusion.Computed<number>,
    Fusion.Computed<number>, Fusion.Computed<number>
)
    local theme = Peek<<ThemeUtils.Theme>>(GetThemeForScope(scope))
    local lgHeight = theme:GetHeight("Lg")

    local function cornerRadius(roundFirst: boolean, roundLast: boolean)
        return Computed(scope, function(use: Fusion.Use): number
            local usedTweenComputeMapSize = use<<UDim2>>(tweenComputeMapSize)
            local usedTweenComputeMapHeightOffset = usedTweenComputeMapSize.Height.Offset
            local usedRowCount = use<<number>>(rowCount)
            local usedRowIdx = use<<number>>(rowIdx)

            local itemCount =
                if usedTweenComputeMapHeightOffset == lgHeight then 1
                else usedRowCount

            if roundFirst and usedRowIdx == 1 then
                return baseRadius
            end

            if roundLast and usedRowIdx == itemCount then
                return baseRadius
            end

            return 0
        end)
    end

    return
        cornerRadius(true, false),
        cornerRadius(true, false),
        cornerRadius(false, true),
        cornerRadius(false, true)
end

local function MapHeader(scope: Fusion.Scope, props: MapHeaderProps)
    local theme = Peek<<ThemeUtils.Theme>>(GetThemeForScope(scope))

    local rowCount, rowIdx = props.RowCount, props.RowIdx
    local variant = props.Variant
    local collapsedState = props.CollapsedState
    local tweenComputeMapSize = props.TweenComputeMapSize

    local innerCornerRadius = theme:GetCornerRadius("Md") - 1
    local rowHeight = theme:GetHeight("Lg") - 2

    local topLeftRadius, topRightRadius, bottomLeftRadius, bottomRightRadius =
        ComputeCornerRadii(
            scope,
            rowCount,
            rowIdx,
            innerCornerRadius,
            tweenComputeMapSize
        )

    return Supercorner.new(scope, {
        BackgroundColor3 = theme:GetBgHighlight(scope, variant),
        Size = UDim2.new(1, 0, 0, rowHeight),
        LayoutOrder = rowIdx,
        TopLeftRadius = topLeftRadius,
        TopRightRadius = topRightRadius,
        BottomLeftRadius = bottomLeftRadius,
        BottomRightRadius = bottomRightRadius,
        MaxCornerRadius = innerCornerRadius,
        Redrawable = true,

        Name = "MapHeader",

        [Children] = {
            Arrow(scope, {
                CollapsedState = collapsedState
            }),

            Text(scope, {
                Text = props.Header,
                FontWeight = Enum.FontWeight.Medium,

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

return MapHeader
