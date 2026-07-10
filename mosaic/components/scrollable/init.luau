--!strict
--!nolint LocalShadow

local Packages = script.Parent.Parent.Parent

local Fusion = require(Packages.fusion)
local Peek, New, Children = Fusion.peek, Fusion.New, Fusion.Children

local Utils = script.Parent.Parent.utils

local FusionUtils = require(Utils.fusionUtils)
local Component, CombineProps =
    FusionUtils.Component, FusionUtils.CombineProps

local ThemeUtils = require(Utils.themeUtils)
local GetThemeForScope = ThemeUtils.GetThemeForScope

local TableUtils = require(Utils.tableUtils)
local TableExtract = TableUtils.Extract

local Assets = require(script.Parent.Parent.assets)

type ScrollableProps = {

}

return Component<<ScrollableProps>>(function(scope, props)
    local theme = Peek<<ThemeUtils.Theme>>(GetThemeForScope(scope))

    local props, children = TableExtract(props, Children)

    return New(scope, "Frame") (CombineProps({
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,

        Name = "Scrollable",

        [Children] = {
            New(scope, "ScrollingFrame") {
                Size = UDim2.fromScale(1, 1),
                CanvasSize = UDim2.fromScale(0, 0),
                AutomaticCanvasSize = Enum.AutomaticSize.Y,
                ScrollBarThickness = 4,
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                ScrollBarImageColor3 = theme:GetBgHighlight(scope, "Tertiary"),
                TopImage = Assets.ScrollTop,
                MidImage = Assets.ScrollMiddle,
                BottomImage = Assets.ScrollBottom,
                ZIndex = 2,

                [Children] = {
                    New(scope, "Frame") {
                        AutomaticSize = Enum.AutomaticSize.XY,
                        BackgroundTransparency = 1,

                        [Children] = children
                    },

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
