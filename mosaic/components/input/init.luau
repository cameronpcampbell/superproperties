--!strict
--!nolint LocalShadow

local Packages = script.Parent.Parent.Parent
local Supercorner = require(Packages.supercorner)

local Fusion = require(Packages.fusion)
local New, Children, Value, Peek, Out, OnEvent, Computed, Tween =
    Fusion.New, Fusion.Children, Fusion.Value, Fusion.peek,
    Fusion.Out, Fusion.OnEvent, Fusion.Computed, Fusion.Tween

local Utils = script.Parent.Parent.utils

local FusionUtils = require(Utils.fusionUtils)
local Component, CombineProps, CreateOutProxy, IsValue =
    FusionUtils.Component, FusionUtils.CombineProps,
    FusionUtils.CreateOutProxy, FusionUtils.IsValue
local ComputeTransforms = FusionUtils.ComputeTransforms
local ComputeUDim2, ComputeUDim = ComputeTransforms.UDim2, ComputeTransforms.UDim

local ThemeUtils = require(Utils.themeUtils)
local GetThemeForScope, GetNextVariant, CalcColorModifier =
    ThemeUtils.GetThemeForScope, ThemeUtils.GetNextVariant,
    ThemeUtils.CalcColorModifier

local TableUtils = require(Utils.tableUtils)
local TableExtract = TableUtils.Extract

local Components = script.Parent.Parent.components
local FocusRing = require(Components.focusRing)

type InputProps = {
	Variant: ThemeUtils.BgVariantLayer?,
	Text: Fusion.UsedAs<string?>?,
	PlaceholderText: Fusion.UsedAs<string>?,
	Width: UDim?,
	LeftChildren: Fusion.Child?,
	RightChildren: Fusion.Child?,
}

return Component<<InputProps>>(function(scope, props)
    local props, variant = TableExtract(props, "Variant", "Tertiary")
    local props, text = TableExtract(props, "Text", "")
    local props, placeholderText = TableExtract(props, "PlaceholderText", "Type here...")
    local props, width = TableExtract(props, "Width", UDim.new(1, 0))
    local props, leftChildren = TableExtract(props, "LeftChildren")
    local props, rightChildren = TableExtract(props, "RightChildren")

    local isHoverState, isFocusState = Value(scope, false), Value(scope, false)
    local themeColorModifier =
        CalcColorModifier(scope, isHoverState, isFocusState, "Stroke")

    local computeVisualText = Computed(scope, function(use, scope)
        local usedText = use<<string?>>(text)
        return if usedText == nil then "" else usedText
    end)

    local textValue = if IsValue(text) then
        (text :: any) :: Fusion.Value<string?, string>
        else nil

    local theme = GetThemeForScope(scope)
    local bgColor = theme:GetBg(scope, variant)
    local textColor = theme:GetFg(scope, "Primary")
    local textPlaceholderColor = theme:GetFg(scope, "Secondary")
    local accentColor = theme:GetAccent(scope, "Primary", themeColorModifier)
    local strokeColor = theme:GetBg(scope, GetNextVariant(variant), themeColorModifier)
    local height = theme:GetHeight(scope, "Lg")
    local cornerRadius = theme:GetCornerRadius(scope, "Md")
    local font = theme:GetFont(scope, "Main", Enum.FontWeight.Medium)
    local fontSize = theme:GetFontSize(scope, "Main", "Title")

    local tweenComputeStrokeColor = Tween<<Color3>>(
        scope,
        Computed(scope, function(use, scope)
            return
                if use<<boolean>>(isFocusState) then
                    use<<Color3>>(accentColor)
                else
                    use<<Color3>>(strokeColor)
        end),
        TweenInfo.new(
            .18, Enum.EasingStyle.Exponential, Enum.EasingDirection.InOut
        )
    )

    local textOutProxy =
        if textValue then
            CreateOutProxy<<string>>(
                scope,
                computeVisualText,
                function(newText) textValue:set(newText) end
            )
        else nil

    return Supercorner.new(scope :: any, CombineProps({
        BackgroundColor3 = bgColor,
        StrokeColor = tweenComputeStrokeColor,
        StrokeThickness = 1,
        Size = ComputeUDim2(scope, width, ComputeUDim(scope, 0, height)),
        CornerRadius = Peek<<number>>(cornerRadius),
        CornerSmoothing = 1,

        Name = "Input",

        [OnEvent "MouseEnter"] = function() isHoverState:set(true) end,
        [OnEvent "MouseLeave"] = function() isHoverState:set(false) end,

        RootChildren = {
            New(scope, "UIFlexItem") {},

            FocusRing(scope, {
                IsFocus = isFocusState,
                -- Focus ring's corner radius can't be changed.
                CornerRadius = Peek<<number>>(cornerRadius)
            })
        },

        [Children] = {
            leftChildren,

            New(scope, "TextBox") {
                Size = UDim2.fromScale(1, 1),
                BackgroundTransparency = 1,
                Text = computeVisualText,
                PlaceholderText = placeholderText,
                TextSize = fontSize,
                TextColor3 = textColor,
                PlaceholderColor3 = textPlaceholderColor,
                FontFace = font,
                ClearTextOnFocus = false,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextTruncate = Enum.TextTruncate.AtEnd,

                [OnEvent "Focused"] = function() isFocusState:set(true) end,
                [OnEvent "FocusLost"] = function() isFocusState:set(false) end,

                [Out "Text"] = textOutProxy,

                [Children] = New(scope, "UIFlexItem") {
                    FlexMode = Enum.UIFlexMode.Shrink
                }
            },

            rightChildren,

            New(scope, "UIListLayout") {
                FillDirection = Enum.FillDirection.Horizontal,
                HorizontalAlignment = Enum.HorizontalAlignment.Left,
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
