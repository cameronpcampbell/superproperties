--!strict
--!nolint LocalShadow

local Packages = script.Parent.Parent.Parent.Parent
local Supercorner = require(Packages.supercorner)
local Typeforge = require(Packages.typeforge)

local Fusion = require(Packages.fusion)
local New, Children, Computed =
    Fusion.New, Fusion.Children, Fusion.Computed

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

local Types = require(script.Parent.types)
local Arrow = require(script.Parent.arrow)

type MapHeaderProps = Typeforge.Flatten<
    Types.BaseMapProps & {
        Header: string,
        HeaderChildrenFrame: Fusion.Child,
        HeaderOverlayFrame: Fusion.Child,
        CollapsedState: Fusion.Value<boolean>,
        TweenComputeMapSize: Fusion.UsedAs<UDim2>
    }
>

local function ComputeCornerRadii(
    scope: Fusion.Scope,
    rowCount: Fusion.UsedAs<number>,
    rowIdx: Fusion.UsedAs<number>,
    baseRadius: Fusion.UsedAs<number>,
    tweenComputeMapSize: Fusion.UsedAs<UDim2>
): (
    Fusion.Computed<number>, Fusion.Computed<number>,
    Fusion.Computed<number>, Fusion.Computed<number>
)
    local theme = GetThemeForScope(scope)
    local height = theme:GetHeight(scope, "Lg")

    local function cornerRadius(roundFirst: boolean, roundLast: boolean)
        return Computed(scope, function(use: Fusion.Use): number
            local usedTweenComputeMapSize = use<<UDim2>>(tweenComputeMapSize)
            local usedTweenComputeMapHeightOffset = usedTweenComputeMapSize.Height.Offset
            local usedRowCount = use<<number>>(rowCount)
            local usedRowIdx = use<<number>>(rowIdx)
            local usedHeight = use<<number>>(height)

            local itemCount =
                if usedTweenComputeMapHeightOffset == usedHeight then 1
                else usedRowCount

            if roundFirst and usedRowIdx == 1 then
                return use<<number>>(baseRadius)
            end

            if roundLast and usedRowIdx == itemCount then
                return use<<number>>(baseRadius)
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
    local rowCount, rowIdx = props.RowCount, props.RowIdx
    local variant = props.Variant
    local collapsedState = props.CollapsedState
    local tweenComputeMapSize = props.TweenComputeMapSize

    local theme = GetThemeForScope(scope)
    local innerCornerRadius = ComputeAdd(scope, theme:GetCornerRadius(scope, "Md"), - 1)
    local rowHeight = ComputeAdd(scope, theme:GetHeight(scope, "Lg"), - 2)

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
        Size = ComputeUDim2(scope, UDim.new(1, 0), ComputeUDim(scope, 0, rowHeight)),
        LayoutOrder = rowIdx,
        TopLeftRadius = topLeftRadius,
        TopRightRadius = topRightRadius,
        BottomLeftRadius = bottomLeftRadius,
        BottomRightRadius = bottomRightRadius,
        MaxCornerRadius = innerCornerRadius,
        Redrawable = true,

        Name = "MapHeader",

        [Children] = {
            New(scope, "Frame") {
                Size = UDim2.fromScale(1, 1),
                BackgroundTransparency = 1,

                Name = "MapHeaderContent",

                [Children] = {
                    Arrow(scope, {
                        CollapsedState = collapsedState
                    }),

                    Text(scope, {
                        Text = props.Header,
                        Size = UDim2.fromScale(1, 0),
                        LayoutOrder = 1,
                        FontWeight = Enum.FontWeight.Medium,

                        [Children] = New(scope, "UIFlexItem") {
                            FlexMode = Enum.UIFlexMode.Shrink
                        }
                    }),

                    props.HeaderChildrenFrame,

                    New(scope, "UIListLayout") {
                        Padding = UDim.new(0, 6),
                        FillDirection = Enum.FillDirection.Horizontal,
                        VerticalAlignment = Enum.VerticalAlignment.Center,
                        SortOrder = Enum.SortOrder.LayoutOrder
                    },

                    New(scope, "UIPadding") {
                        PaddingLeft = UDim.new(0, 6),
                        PaddingRight = UDim.new(0, 6)
                    }
                }
            },

            props.HeaderOverlayFrame
        }
    })
end

return MapHeader
