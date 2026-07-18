--!strict
--!nolint LocalShadow

local Packages = script.Parent.Parent.Parent

local Fusion = require(Packages.fusion)
local New, Children, Value, Peek, OnEvent, Tween =
    Fusion.New, Fusion.Children, Fusion.Value,
    Fusion.peek, Fusion.OnEvent, Fusion.Tween

local Utils = script.Parent.Parent.utils

local FusionUtils = require(Utils.fusionUtils)
local Component, ChildrenTransform =
    FusionUtils.Component, FusionUtils.ChildrenTransform
local ComputeTransforms = FusionUtils.ComputeTransforms
local ComputeUDim2, ComputeUDim = ComputeTransforms.UDim2, ComputeTransforms.UDim

local ThemeUtils = require(Utils.themeUtils)
local GetThemeForScope, CalcColorModifier =
    ThemeUtils.GetThemeForScope, ThemeUtils.CalcColorModifier

local TableUtils = require(Utils.tableUtils)
local TableExtract = TableUtils.Extract

local Components = script.Parent
local HighlightSupercorner = require(Components.highlightSupercorner)
local Text = require(Components.text)

type ButtonProps = {
	Variant: ThemeUtils.AccentVariant?,
	Width: UDim?
}

local function TransformChild(scope: Fusion.Scope, child: unknown): Fusion.Child?
    local childTypeof = typeof(child)

    if childTypeof ~= "string" then
        return if childTypeof == "Instance" then child :: Fusion.Child else nil

    end

    local theme = GetThemeForScope(scope)
    local accentFgColor = theme:GetAccentFg(scope, "Primary")

    if string.match(child :: string, "^rbxassetid://%d+$") then

        return New (scope, "ImageLabel") {
            Size = UDim2.fromOffset(9, 9),
            BackgroundTransparency = 1,
            ImageColor3 = accentFgColor,
            Image = child
        }

    else
        return Text (scope, {
            Text = child :: string,
            TextColor3 = accentFgColor,
            UseAccentFg = true
        })

    end
end

return Component<<ButtonProps>>(function(scope, props)
    local props, variant = TableExtract(props, "Variant", "Primary")
    local props, width = TableExtract(props, "Width", UDim.new(1, 0))
    local props, children = TableExtract(props, Children)

    local isHoverState, isFocusState = Value(scope, false), Value(scope, false)
    local themeColorModifier = CalcColorModifier(scope, isHoverState, isFocusState)

    local theme = GetThemeForScope(scope)
    local accentColor = theme:GetAccent(scope, variant, themeColorModifier)
    local cornerRadius = theme:GetCornerRadius(scope, "Md")
    local height = theme:GetHeight(scope, "Lg")

    return HighlightSupercorner(scope, {
        Button = true,
        GradientTransparency = 0.78,
        BackgroundColor3 = Tween<<Color3>>(
            scope, accentColor,
            TweenInfo.new(
                .25, Enum.EasingStyle.Exponential, Enum.EasingDirection.InOut
            )
        ),
        StrokeThickness = 1,
        Size = ComputeUDim2(scope, width, ComputeUDim(scope, 0, height)),
        CornerRadius = Peek<<number>>(cornerRadius),
        CornerSmoothing = 1,

        [OnEvent "MouseEnter"] = function() isHoverState:set(true) end,
        [OnEvent "MouseLeave"] = function() isHoverState:set(false) end,

        [OnEvent "MouseButton1Down"] = function() isFocusState:set(true) end,
        [OnEvent "MouseButton1Up"] = function() isFocusState:set(false) end,

        RootChildren = New(scope, "UIFlexItem") {},

        [Children] = {
            ChildrenTransform(scope, TransformChild, children),

            New(scope, "UIListLayout") {
                FillDirection = Enum.FillDirection.Horizontal,
                HorizontalAlignment = Enum.HorizontalAlignment.Center,
                VerticalAlignment = Enum.VerticalAlignment.Center,
                Padding = UDim.new(0, 6)
            }
        },

        Name = "Button"
    }, props)
end)
