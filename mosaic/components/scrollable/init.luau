--!strict
--!nolint LocalShadow

local Packages = script.Parent.Parent.Parent

local Fusion = require(Packages.fusion)
local New, Children, Out, Computed =
    Fusion.New, Fusion.Children, Fusion.Out,
    Fusion.Computed

local Utils = script.Parent.Parent.utils

local FusionUtils = require(Utils.fusionUtils)
local Component, CombineProps, ComposeTransparency =
    FusionUtils.Component, FusionUtils.CombineProps,
    FusionUtils.ComposeTransparency

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
    AutomaticSize: Fusion.UsedAs<Enum.AutomaticSize>?,
    AutomaticCanvasSize: Fusion.UsedAs<Enum.AutomaticSize>?,
    Padding: Fusion.UsedAs<UDim>?,
    Transparency: Fusion.UsedAs<number>?,
    RootChildren: Fusion.Child?,
}

return Component<<ScrollableProps>>(function(scope, props)
    local props, variant = TableExtract(props, "Variant", "Tertiary")
    local props, children = TableExtract(props, Children)
    local props, rootChildren = TableExtract(props, "RootChildren")
    local props, outAbsolutePosition = TableExtract(props, "OutAbsolutePosition")
    local props, outAbsoluteSize = TableExtract(props, "OutAbsoluteSize")
    local props, outCanvasPosition = TableExtract(props, "OutCanvasPosition")
    local props, canvasSize = TableExtract(props, "CanvasSize", UDim2.fromScale(0, 0))
    local props, automaticSize =
        TableExtract(props, "AutomaticSize", Enum.AutomaticSize.None)
    local props, automaticCanvasSize =
        TableExtract(props, "AutomaticCanvasSize", Enum.AutomaticSize.Y)
    local props, padding = TableExtract(props, "Padding", UDim.new(0, 4))
    local props, transparency = TableExtract(props, "Transparency", 0)

    local theme = GetThemeForScope(scope)
    local scrollBarColor = theme:GetBgHighlight(scope, GetNextVariant(scope, variant))
    local scrollBarUnderlayColor = theme:GetBgHighlight(scope, variant)
    local composedTransparency = ComposeTransparency(scope, 0, transparency)

    local copmputePadding = Computed(scope, function(use, scope)
        local usedPadding = use<<UDim>>(padding)

        return UDim.new(usedPadding.Scale, 4 + usedPadding.Offset)
    end)

    return New(scope, "Frame") (CombineProps({
        Size = UDim2.fromScale(1, 1),
        AutomaticSize = automaticSize,
        BackgroundTransparency = 1,

        Name = "Scrollable",

        [Children] = {
            rootChildren,

            New(scope, "ScrollingFrame") {
                Size = UDim2.fromScale(1, 1),
                AutomaticSize = automaticSize,
                CanvasSize = canvasSize,
                AutomaticCanvasSize = automaticCanvasSize,
                ScrollBarThickness = 4,
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                ScrollBarImageColor3 = scrollBarColor,
                ScrollBarImageTransparency = composedTransparency,
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
                        PaddingRight = copmputePadding,
                    },
                }
            },

            New(scope, "Frame") {
                Size = UDim2.new(0, 4, 1, 0),
                Position = UDim2.new(1, -4, 0, 0),
                BackgroundColor3 = scrollBarUnderlayColor,
                BackgroundTransparency = composedTransparency,

                [Children] = New(scope, "UICorner") {
                    CornerRadius = UDim.new(1, 0)
                }
            }
        }
    }, props))
end)
