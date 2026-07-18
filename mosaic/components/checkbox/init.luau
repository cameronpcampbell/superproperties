--!strict
--!nolint LocalShadow

local Packages = script.Parent.Parent.Parent
local Supercorner = require(Packages.supercorner)

local Fusion = require(Packages.fusion)
local New, Children, Value, Peek, Computed, OnEvent, Tween =
    Fusion.New, Fusion.Children, Fusion.Value, Fusion.peek,
    Fusion.Computed, Fusion.OnEvent, Fusion.Tween

local Utils = script.Parent.Parent.utils

local FusionUtils = require(Utils.fusionUtils)
local Component, CombineProps, CoerceToValue =
    FusionUtils.Component, FusionUtils.CombineProps, FusionUtils.CoerceToValue
local ComputeTransforms = FusionUtils.ComputeTransforms
local ComputeUDim2FromOffset = ComputeTransforms.UDim2FromOffset

local ThemeUtils = require(Utils.themeUtils)
local GetThemeForScope, CalcColorModifier =
    ThemeUtils.GetThemeForScope, ThemeUtils.CalcColorModifier

local TableUtils = require(Utils.tableUtils)
local TableExtract = TableUtils.Extract

local Components = script.Parent
local HighlightGradient = require(Components.highlightGradient)

local Assets = require(script.Parent.Parent.assets)

type CheckboxProps = {
    Checked: Fusion.UsedAs<boolean>?,
    Disabled: Fusion.UsedAs<boolean>?,
    OnChanged: ((checked: boolean) -> ())?
}

local DisabledTransparency = 0.5
local TransparencyTweenInfo = TweenInfo.new(
    0.25,
    Enum.EasingStyle.Exponential,
    Enum.EasingDirection.InOut
)

return Component<<CheckboxProps>>(function(scope, props)
    local props, checked = TableExtract(props, "Checked", true)
    local props, disabled = TableExtract(props, "Disabled", true)
    local props, onChanged = TableExtract(props, "OnChanged")

    local checkedState = CoerceToValue<<boolean>>(scope, checked)

    local isHoverState, isFocusState = Value(scope, false), Value(scope, false)
    local themeColorModifier = CalcColorModifier(scope, isHoverState, isFocusState)

    local checkedTransparency = Tween<<number>>(
        scope,
        Computed(scope, function(use, scope)
            if not use<<boolean>>(checkedState) then return 1 end

            return
                if use<<boolean>>(disabled) then DisabledTransparency
                else 0
        end),
        TransparencyTweenInfo
    )

    local uncheckedTransparency = Tween<<number>>(
        scope,
        Computed(scope, function(use, scope)
            if use<<boolean>>(checkedState) then return 1 end

            return
                if use<<boolean>>(disabled) then DisabledTransparency
                else 0
        end),
        TransparencyTweenInfo
    )

    local theme = GetThemeForScope(scope)
    local accentColor = theme:GetAccent(scope, "Primary", themeColorModifier)
    local accentFgColor = theme:GetAccentFg(scope, "Primary")
    local strokeColor = theme:GetFg(scope, "Primary")
    local height = theme:GetHeight(scope, "Sm")
    local cornerRadius = theme:GetCornerRadius(scope, "Sm")

    local gradientEnabled = Computed(scope, function(use): boolean
        return not use<<boolean>>(disabled)
    end)

    return HighlightGradient(scope, CombineProps({
        Button = true,
        Enabled = gradientEnabled,
        GradientTransparency = 0.78,
        BackgroundColor3 = Tween<<Color3>>(
            scope, accentColor,
            TweenInfo.new(
                .25, Enum.EasingStyle.Exponential, Enum.EasingDirection.InOut
            )
        ),
        BackgroundTransparency = checkedTransparency,
        StrokeTransparency = checkedTransparency,
        StrokeThickness = 1,
        Size = ComputeUDim2FromOffset(scope, height, height),
        CornerRadius = Peek<<number>>(cornerRadius),
        CornerSmoothing = 1,

        [OnEvent "MouseEnter"] = function()
            if Peek<<boolean>>(disabled) then return end

            isHoverState:set(true)
        end,

        [OnEvent "MouseLeave"] = function()
            isHoverState:set(false)
        end,

        [OnEvent "MouseButton1Down"] = function()
            if Peek<<boolean>>(disabled) then return end

            isFocusState:set(true)
        end,

        [OnEvent "MouseButton1Up"] = function()
            isFocusState:set(false)
        end,

        [OnEvent "MouseButton1Click"] = function()
            if Peek<<boolean>>(disabled) then return end

            local nextChecked = not Peek<<boolean>>(checkedState)
            if onChanged then
                onChanged(nextChecked)
                return
            end

            checkedState:set(nextChecked)
        end,

        RootChildren = {
            Supercorner.new(scope, {
                Size = UDim2.fromScale(1, 1),
                StrokeThickness = 1,
                BackgroundTransparency = 1,
                StrokeColor = Tween<<Color3>>(
                    scope, strokeColor,
                    TweenInfo.new(
                        .25, Enum.EasingStyle.Exponential, Enum.EasingDirection.InOut
                    )
                ),
                CornerRadius = Peek<<number>>(cornerRadius),
                StrokeTransparency = uncheckedTransparency
            }),

            New(scope, "UIFlexItem") {},
        },

        [Children] = {
            New(scope, "ImageLabel") {
                Image = Assets.CheckboxTrue,
                ImageColor3 = accentFgColor,
                Size = UDim2.fromScale(1, 1),
                BackgroundTransparency = 1,
                ImageTransparency = checkedTransparency
            },
        },

        Name = "Button"
    }, props))
end)
