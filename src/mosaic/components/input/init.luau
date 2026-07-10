--!strict
--!nolint LocalShadow

local Packages = script.Parent.Parent.Parent.packages
local Fusion = require(Packages.fusion)

local Utils = script.Parent.Parent.utils
local FusionUtils = require(Utils.fusionUtils)
local TableUtils = require(Utils.tableUtils)
local ThemeUtils = require(Utils.themeUtils)

local Components = script.Parent.Parent.components
local FocusRing = require(Components.focusRing)

local Supercorner = require(Packages.supercorner)

local Peek, New, Children, Value, OnEvent =
    Fusion.peek, Fusion.New, Fusion.Children, Fusion.Value, Fusion.OnEvent
local Component, CombineProps =
    FusionUtils.Component, FusionUtils.CombineProps
local TableExtract = TableUtils.Extract
local GetThemeForScope, GetNextVariant, CalcColorModifier =
    ThemeUtils.GetThemeForScope, ThemeUtils.GetNextVariant,
    ThemeUtils.CalcColorModifier

type InputProps = {
	Variant: ThemeUtils.BgVariantLayer?,
	Text: Fusion.UsedAs<string>?,
	PlaceholderText: Fusion.UsedAs<string>?,
	Width: UDim?,
	LeftChildren: Fusion.Child?,
	RightChildren: Fusion.Child?,
}

return Component<<InputProps>>(function(scope, props)
    local theme = Peek<<ThemeUtils.Theme>>(GetThemeForScope(scope))

    local props, variant = TableExtract(props, "Variant", "Tertiary")
    local props, text = TableExtract(props, "Text", "")
    local props, placeholderText = TableExtract(props, "PlaceholderText", "Type here...")
    local props, width = TableExtract(props, "Width", UDim.new(1, 0))
    local props, leftChildren = TableExtract(props, "LeftChildren")
    local props, rightChildren = TableExtract(props, "RightChildren")

    local isHoverState, isFocusState = Value(scope, false), Value(scope, false)
    local themeColorModifier = CalcColorModifier(scope, isHoverState, isFocusState, "Stroke")

    local tweenComputeStrokeColor = Fusion.Tween<<Color3>>(
        scope,
        Fusion.Computed(scope, function(use, scope)
            return
                if use<<boolean>>(isFocusState) then
                    use<<Color3>>(theme:GetAccent(scope, "Primary", themeColorModifier))
                else
                    use<<Color3>>(theme:GetBg(scope, GetNextVariant(variant), themeColorModifier))
        end),
        TweenInfo.new(
            .25, Enum.EasingStyle.Exponential, Enum.EasingDirection.InOut
        )
    )

    return Supercorner.new(scope :: any, CombineProps({
        BackgroundColor3 = theme:GetBg(scope, variant),
        StrokeColor = tweenComputeStrokeColor,
        StrokeThickness = 1,
        Size = UDim2.new(width, UDim.new(0, theme:GetHeight("Lg"))),
        CornerRadius = theme:GetCornerRadius("Md"),
        CornerSmoothing = 1,

        Name = "Input",

        [OnEvent "MouseEnter"] = function() isHoverState:set(true) end,
        [OnEvent "MouseLeave"] = function() isHoverState:set(false) end,

        RootChildren = {
            New(scope, "UIFlexItem") {},

            FocusRing(scope, {
                IsFocus = isFocusState,
                CornerRadius = theme:GetCornerRadius("Md")
            })
        },

        [Children] = {
            leftChildren,

            New(scope, "TextBox") {
                Size = UDim2.fromScale(1, 1),
                BackgroundTransparency = 1,
                Text = text,
                PlaceholderText = placeholderText,
                TextSize = theme:GetFontSize("Main", "Title"),
                TextColor3 = theme:GetFg(scope, "Primary"),
                PlaceholderColor3 = theme:GetFg(scope, "Secondary"),
                FontFace = theme:GetFont("Main", Enum.FontWeight.Medium),
                ClearTextOnFocus = false,
                TextXAlignment = Enum.TextXAlignment.Left,

                [OnEvent "Focused"] = function() isFocusState:set(true) end,
                [OnEvent "FocusLost"] = function() isFocusState:set(false) end,
            },

            rightChildren,

            New(scope, "UIListLayout") {
                FillDirection = Enum.FillDirection.Horizontal,
                HorizontalAlignment = Enum.HorizontalAlignment.Left,
                HorizontalFlex = Enum.UIFlexAlignment.Fill,
                VerticalAlignment = Enum.VerticalAlignment.Center,
                Padding = UDim.new(0, 6)
            },

            New(scope, "UIPadding") {
                PaddingLeft = UDim.new(0, 7),
                PaddingRight = UDim.new(0, 7),
            },
        }
    }, props))
end)
