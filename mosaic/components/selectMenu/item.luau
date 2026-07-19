--!strict

local Packages = script.Parent.Parent.Parent.Parent

local Fusion = require(Packages.fusion)
local New, Children, Computed, Value, Peek, OnEvent, Tween =
    Fusion.New, Fusion.Children, Fusion.Computed, Fusion.Value,
    Fusion.peek, Fusion.OnEvent, Fusion.Tween

local Utils = script.Parent.Parent.Parent.utils

local FusionUtils = require(Utils.fusionUtils)
local ComputeTransforms, ComputeMath, ComposeTransparency =
    FusionUtils.ComputeTransforms, FusionUtils.ComputeMath,
    FusionUtils.ComposeTransparency
local ComputeUDim2, ComputeUDim = ComputeTransforms.UDim2, ComputeTransforms.UDim
local ComputeAdd = ComputeMath.Add

local ThemeUtils = require(Utils.themeUtils)
local GetThemeForScope, CalcColorModifier =
    ThemeUtils.GetThemeForScope, ThemeUtils.CalcColorModifier

local Components = script.Parent.Parent
local HighlightSupercorner = require(Components.highlightSupercorner)
local Text = require(Components.text)

type SelectMenuItemProps = {
    Text: string,
    SelectedIdxValue: Fusion.Value<number?>,
    Idx: number,
    Transparency: Fusion.UsedAs<number>,
    Interactable: Fusion.UsedAs<boolean>
}

local function SelectMenuItem(
    scope: Fusion.Scope,
    props: SelectMenuItemProps
)
    local SelectedIdxValue = props.SelectedIdxValue
    local idx = props.Idx

    local isHoverState, isFocusState = Value(scope, false), Value(scope, false)
    local accentColorModifier = CalcColorModifier(scope, isHoverState, isFocusState)

    local computeSelected = Computed(scope, function(use, scope)
        local usedSelectedIdx = use<<number?>>(SelectedIdxValue)

        return usedSelectedIdx == idx
    end)

    local computeGradientTransparency = Computed(scope, function(use, scope)
        local usedComputeSelected = use<<boolean>>(computeSelected)
        local usedIsHoverState = use<<boolean>>(isHoverState)

        if usedComputeSelected then
            return 0.95

        elseif usedIsHoverState then
            return 0.96

        else
            return 1
        end
    end)

    local computeBgTransparency = Computed(scope, function(use, scope)
        local usedComputeSelected = use<<boolean>>(computeSelected)
        local usedIsHoverState = use<<boolean>>(isHoverState)

        if usedComputeSelected then
            return 0.8

        elseif usedIsHoverState then
            return 0.88

        else
            return 1
        end
    end)

    local theme = GetThemeForScope(scope)
    local accentColor = theme:GetAccent(scope, "Primary", accentColorModifier)
    local cornerRadius = ComputeAdd(scope, theme:GetCornerRadius(scope, "Md"), -2)
    local height = ComputeAdd(scope, theme:GetHeight(scope, "Lg"), -4)
    local transitionTweenInfo = TweenInfo.new(
        .25,
        Enum.EasingStyle.Exponential,
        Enum.EasingDirection.InOut
    )
    local animatedGradientTransparency = Tween<<number>>(
        scope,
        computeGradientTransparency,
        transitionTweenInfo
    )
    local animatedBackgroundTransparency = Tween<<number>>(
        scope,
        computeBgTransparency,
        transitionTweenInfo
    )
    local composedGradientTransparency = ComposeTransparency(
        scope,
        animatedGradientTransparency,
        props.Transparency
    )
    local composedBackgroundTransparency = ComposeTransparency(
        scope,
        animatedBackgroundTransparency,
        props.Transparency
    )
    local composedOpaqueTransparency = ComposeTransparency(
        scope,
        0,
        props.Transparency
    )

    return HighlightSupercorner(scope, {
        Button = true,
        Interactable = props.Interactable,
        GradientTransparency = composedGradientTransparency,
        BackgroundColor3 = Tween<<Color3>>(
            scope,
            accentColor,
            transitionTweenInfo
        ),
        BackgroundTransparency = composedBackgroundTransparency,
        StrokeTransparency = composedOpaqueTransparency,
        StrokeThickness = 1,
        Size = ComputeUDim2(scope, UDim.new(1, 0), ComputeUDim(scope, 0, height)),
        CornerRadius = Peek<<number>>(cornerRadius),
        CornerSmoothing = 1,

        RootChildren = New(scope, "UIFlexItem") {},

        [OnEvent "MouseEnter"] = function() isHoverState:set(true) end,
        [OnEvent "MouseLeave"] = function() isHoverState:set(false) end,

        [OnEvent "MouseButton1Down"] = function() isFocusState:set(true) end,
        [OnEvent "MouseButton1Up"] = function() isFocusState:set(false) end,

        [OnEvent "MouseButton1Click"] = function()
            local peekedSelectedIdx = Peek<<number?>>(SelectedIdxValue)

            SelectedIdxValue:set(if peekedSelectedIdx == idx then nil else idx)
        end,

        [Children] = {
            Text(scope, {
                Text = props.Text,
                TextTransparency = composedOpaqueTransparency
            }),

            New(scope, "UIListLayout") {
                FillDirection = Enum.FillDirection.Horizontal,
                HorizontalAlignment = Enum.HorizontalAlignment.Left,
                VerticalAlignment = Enum.VerticalAlignment.Center,
                Padding = UDim.new(0, 6)
            },

            New(scope, "UIPadding") {
                PaddingLeft = UDim.new(0, 3),
                PaddingRight = UDim.new(0, 3),
            }
        },

        Name = "SelectMenuItem"
    })
end

return SelectMenuItem
