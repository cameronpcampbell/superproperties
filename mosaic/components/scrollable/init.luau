--!strict
--!nolint LocalShadow

local Packages = script.Parent.Parent.Parent

local Fusion = require(Packages.fusion)
local Typeforge = require(Packages.typeforge)
local Peek, New, Children, Out =
    Fusion.peek, Fusion.New, Fusion.Children, Fusion.Out

local Utils = script.Parent.Parent.utils

local FusionUtils = require(Utils.fusionUtils)
local Component, CombineProps =
    FusionUtils.Component, FusionUtils.CombineProps

local ThemeUtils = require(Utils.themeUtils)
local GetThemeForScope = ThemeUtils.GetThemeForScope

local TableUtils = require(Utils.tableUtils)
local TableExtract = TableUtils.Extract

local Assets = require(script.Parent.Parent.assets)

export type ScrollableProps = {
    OutCanvasPosition: Fusion.Value<Vector2>?,
    OutAbsolutePosition: Fusion.Value<Vector2>?,
    OutAbsoluteSize: Fusion.Value<Vector2>?,
    CanvasSize: Fusion.UsedAs<UDim2>?,
    AutomaticCanvasSize: Fusion.UsedAs<Enum.AutomaticSize>?
}

export type ScrollableOverrides = Typeforge.FlattenTable<
    Typeforge.Partial<ScrollableProps> & Fusion.PropertyTable
>

return Component<<ScrollableProps>>(function(scope, props)
    local theme = Peek<<ThemeUtils.Theme>>(GetThemeForScope(scope))

    local props, children = TableExtract(props, Children)
    local props, outAbsolutePosition = TableExtract(props, "OutAbsolutePosition")
    local props, outAbsoluteSize = TableExtract(props, "OutAbsoluteSize")
    local props, outCanvasPosition = TableExtract(props, "OutCanvasPosition")
    local props, canvasSize = TableExtract(props, "CanvasSize", UDim2.fromScale(0, 0))
    local props, automaticCanvasSize =
        TableExtract(props, "AutomaticCanvasSize", Enum.AutomaticSize.Y)

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
                ScrollBarImageColor3 = theme:GetBgHighlight(scope, "Tertiary"),
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
                BackgroundColor3 = theme:GetBgHighlight(scope, "Secondary"),

                [Children] = New(scope, "UICorner") {
                    CornerRadius = UDim.new(1, 0)
                }
            }
        }
    }, props))
end)
