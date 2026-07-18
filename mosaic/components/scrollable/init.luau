--!strict
--!nolint LocalShadow

local Packages = script.Parent.Parent.Parent

local Fusion = require(Packages.fusion)
local New, Children, Out =
    Fusion.New, Fusion.Children, Fusion.Out

local Utils = script.Parent.Parent.utils

local FusionUtils = require(Utils.fusionUtils)
local Component, CombineProps =
    FusionUtils.Component, FusionUtils.CombineProps

local ThemeUtils = require(Utils.themeUtils)
local GetThemeForScope, GetNextVariant =
    ThemeUtils.GetThemeForScope, ThemeUtils.GetNextVariant

local TableUtils = require(Utils.tableUtils)
local TableExtract = TableUtils.Extract

local Assets = require(script.Parent.Parent.assets)

export type ScrollableProps = {
    Variant: Fusion.UsedAs<ThemeUtils.BgVariantLayer>?,
    OutCanvasPosition: Fusion.Value<Vector2>?,
    OutAbsolutePosition: Fusion.Value<Vector2>?,
    OutAbsoluteSize: Fusion.Value<Vector2>?,
    CanvasSize: Fusion.UsedAs<UDim2>?,
    AutomaticCanvasSize: Fusion.UsedAs<Enum.AutomaticSize>?
}

return Component<<ScrollableProps>>(function(scope, props)
    local props, variant = TableExtract(props, "Variant", "Tertiary")
    local props, children = TableExtract(props, Children)
    local props, outAbsolutePosition = TableExtract(props, "OutAbsolutePosition")
    local props, outAbsoluteSize = TableExtract(props, "OutAbsoluteSize")
    local props, outCanvasPosition = TableExtract(props, "OutCanvasPosition")
    local props, canvasSize = TableExtract(props, "CanvasSize", UDim2.fromScale(0, 0))
    local props, automaticCanvasSize =
        TableExtract(props, "AutomaticCanvasSize", Enum.AutomaticSize.Y)

    local theme = GetThemeForScope(scope)
    local scrollBarColor = theme:GetBgHighlight(scope, GetNextVariant(scope, variant))
    local scrollBarUnderlayColor = theme:GetBgHighlight(scope, variant)

    return New(scope, "Frame") (CombineProps({
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,

        Name = "Scrollable",

        [Children] = {
            New(scope, "ScrollingFrame") {
                Size = UDim2.fromScale(1, 1),
                CanvasSize = canvasSize,
                AutomaticCanvasSize = automaticCanvasSize,
                ScrollBarThickness = 4,
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                ScrollBarImageColor3 = scrollBarColor,
                TopImage = Assets.ScrollTop,
                MidImage = Assets.ScrollMiddle,
                BottomImage = Assets.ScrollBottom,
                ZIndex = 2,

                [Out "AbsolutePosition"] = outAbsolutePosition,
                [Out "AbsoluteSize"] = outAbsoluteSize,
                [Out "CanvasPosition"] = outCanvasPosition,

                [Children] = {
                    children,

                    New (scope, "UIPadding") {
                        PaddingRight = UDim.new(0, 8),
                    },
                }
            },

            New(scope, "Frame") {
                Size = UDim2.new(0, 4, 1, 0),
                Position = UDim2.new(1, -4, 0, 0),
                BackgroundColor3 = scrollBarUnderlayColor,

                [Children] = New(scope, "UICorner") {
                    CornerRadius = UDim.new(1, 0)
                }
            }
        }
    }, props))
end)
