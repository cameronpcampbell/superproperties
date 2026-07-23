--!strict
--!nolint LocalShadow

local Packages = script.Parent.Parent.Parent

local Fusion = require(Packages.fusion)
local New, Children, Value, Peek, Computed, OnEvent, Tween =
    Fusion.New, Fusion.Children, Fusion.Value, Fusion.peek,
    Fusion.Computed, Fusion.OnEvent, Fusion.Tween

local Utils = script.Parent.Parent.utils

local FusionUtils = require(Utils.fusionUtils)
local Component, ChildrenTransform, Oktween =
    FusionUtils.Component, FusionUtils.ChildrenTransform, FusionUtils.Oktween
local ComputeTransforms = FusionUtils.ComputeTransforms
local ComputeUDim2, ComputeUDim = ComputeTransforms.UDim2, ComputeTransforms.UDim

local ThemeUtils = require(Utils.themeUtils)
local GetThemeForScope, CalcColorModifier =
    ThemeUtils.GetThemeForScope, ThemeUtils.CalcColorModifier

local TableUtils = require(Utils.tableUtils)
local TableExtract = TableUtils.Extract

local CoreComponents = script.Parent.Parent.coreComponents
local CoreButton = require(CoreComponents.button)

local Components = script.Parent
local HighlightSupercorner = require(Components.highlightSupercorner)
local Text = require(Components.text)

type ButtonProps = {
	Variant: ThemeUtils.AccentVariant?,
	Width: UDim?,
	Disabled: Fusion.UsedAs<boolean>?,
	[string | Fusion.SpecialKey]: any
}

local DisabledTransparency = 0.5
local TransparencyTweenInfo = TweenInfo.new(
    0.25,
    Enum.EasingStyle.Exponential,
    Enum.EasingDirection.InOut
)

local function TransformChild(
    scope: Fusion.Scope,
    child: unknown,
    transparency: Fusion.UsedAs<number>
): Fusion.Child?
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
            ImageTransparency = transparency,
            Image = child
        }

    else
        return Text (scope, {
            Text = child :: string,
            TextColor3 = accentFgColor,
            TextTransparency = transparency,
            UseAccentFg = true
        })

    end
end

return Component<<ButtonProps>>(function(scope, props)
    local props, variant = TableExtract(props, "Variant", "Primary")
    local props, width = TableExtract(props, "Width", UDim.new(1, 0))
    local props, disabled = TableExtract(props, "Disabled", false)
    local props, children = TableExtract(props, Children)

    local isHoverState, isFocusState = Value(scope, false), Value(scope, false)
    local themeColorModifier = CalcColorModifier(scope, isHoverState, isFocusState)

    local disabledTransparency = Tween<<number>>(
        scope,
        Computed(scope, function(use, scope)
            return
                if use<<boolean>>(disabled) then DisabledTransparency
                else 0
        end),
        TransparencyTweenInfo
    )

    local theme = GetThemeForScope(scope)
    local accentColor = theme:GetAccent(scope, variant, themeColorModifier)
    local cornerRadius = theme:GetCornerRadius(scope, "Md")
    local height = theme:GetHeight(scope, "Lg")

    local gradientEnabled = Computed(scope, function(use): boolean
        return not use<<boolean>>(disabled)
    end)

    return CoreButton(scope, HighlightSupercorner, {
        Button = true,
        Enabled = gradientEnabled,
        GradientTransparency = 0.78,
        BackgroundColor3 = Oktween(
            scope, accentColor,
            TweenInfo.new(
                .25, Enum.EasingStyle.Exponential, Enum.EasingDirection.InOut
            )
        ),
        BackgroundTransparency = disabledTransparency,
        StrokeTransparency = disabledTransparency,
        StrokeThickness = 1,
        Size = ComputeUDim2(scope, width, ComputeUDim(scope, 0, height)),
        CornerRadius = Peek<<number>>(cornerRadius),
        CornerSmoothing = 1,
        Interactable = gradientEnabled,

        [OnEvent "MouseEnter"] = function()
            if Peek<<boolean>>(disabled) then return end

            isHoverState:set(true)
        end,

        [OnEvent "MouseLeave"] = function() isHoverState:set(false) end,

        [OnEvent "MouseButton1Down"] = function()
            if Peek<<boolean>>(disabled) then return end

            isFocusState:set(true)
        end,

        [OnEvent "MouseButton1Up"] = function() isFocusState:set(false) end,

        RootChildren = New(scope, "UIFlexItem") {},

        [Children] = {
            ChildrenTransform(scope, function(childScope, child)
                return TransformChild(
                    childScope,
                    child,
                    disabledTransparency
                )
            end, children),

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
