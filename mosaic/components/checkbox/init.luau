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
local Component, CoerceToValue, Oktween =
    FusionUtils.Component, FusionUtils.CoerceToValue, FusionUtils.Oktween
local ComputeTransforms = FusionUtils.ComputeTransforms
local ComputeUDim2FromOffset = ComputeTransforms.UDim2FromOffset

local ThemeUtils = require(Utils.themeUtils)
local GetThemeForScope, CalcColorModifier =
    ThemeUtils.GetThemeForScope, ThemeUtils.CalcColorModifier

local TableUtils = require(Utils.tableUtils)
local TableExtract = TableUtils.Extract

local Components = script.Parent
local HighlightSupercorner = require(Components.highlightSupercorner)

local CoreComponents = script.Parent.Parent.coreComponents
local TransparencyGated = require(CoreComponents.transparencyGated)

local Assets = require(script.Parent.Parent.assets)

export type Checked = boolean | "Mixed"

type CheckboxProps = {
    Checked: Fusion.UsedAs<Checked>?,
    Disabled: Fusion.UsedAs<boolean>?,
    OnChanged: ((checked: boolean) -> ())?
}

local DisabledTransparency = 0.5
local TransparencyTweenInfo = TweenInfo.new(
    0.25,
    Enum.EasingStyle.Exponential,
    Enum.EasingDirection.InOut
)

local function NewImageLabel(
    scope: Fusion.Scope,
    props: { [any]: any }
): Fusion.Child
    return New(scope, "ImageLabel")(props)
end

return Component<<CheckboxProps>>(function(scope, props)
    local props, checked = TableExtract(props, "Checked", true)
    local props, disabled = TableExtract(props, "Disabled", true)
    local props, onChanged = TableExtract(props, "OnChanged")

    local checkedState = CoerceToValue<<Checked>>(scope, checked)

    local isHoverState, isFocusState = Value(scope, false), Value(scope, false)
    local themeColorModifier = CalcColorModifier(scope, isHoverState, isFocusState)

    local checkedTransparency = Tween<<number>>(
        scope,
        Computed(scope, function(use, scope)
            local usedCheckedState = use<<Checked>>(checkedState)
            local usedDisabled = use<<boolean>>(disabled)

            if usedCheckedState ~= true then return 1 end

            return
                if usedDisabled then DisabledTransparency
                else 0
        end),
        TransparencyTweenInfo
    )

    local strokeTransparency = Tween<<number>>(
        scope,
        Computed(scope, function(use, scope)
            local usedCheckedState = use<<Checked>>(checkedState)
            local usedDisabled = use<<boolean>>(disabled)

            if usedCheckedState == true then return 1 end

            return
                if usedDisabled then DisabledTransparency
                else 0
        end),
        TransparencyTweenInfo
    )

    local mixedTransparency = Tween<<number>>(
        scope,
        Computed(scope, function(use, scope)
            local usedCheckedState = use<<Checked>>(checkedState)
            local usedDisabled = use<<boolean>>(disabled)

            if usedCheckedState ~= "Mixed" then return 1 end

            return
                if usedDisabled then DisabledTransparency
                else 0
        end),
        TransparencyTweenInfo
    )

    local theme = GetThemeForScope(scope)
    local accentColor = theme:GetAccent(scope, "Primary", themeColorModifier)
    local accentFgColor = theme:GetAccentFg(scope, "Primary")
    local strokeColor = theme:GetFg(scope, "Primary", themeColorModifier)
    local height = theme:GetHeight(scope, "Sm")
    local cornerRadius = theme:GetCornerRadius(scope, "Sm")

    local gradientEnabled = Computed(scope, function(use): boolean
        return not use<<boolean>>(disabled)
    end)

    return HighlightSupercorner(scope, {
        Button = true,
        Enabled = gradientEnabled,
        GradientTransparency = 0.82,
        BackgroundColor3 = Oktween(
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

            local nextChecked = Peek<<Checked>>(checkedState) ~= true
            if onChanged then
                onChanged(nextChecked)
                return
            end

            checkedState:set(nextChecked)
        end,

        RootChildren = {
            TransparencyGated(scope, Supercorner.new :: any, {
                GatedTransparencyProperty = "StrokeTransparency",
                Size = UDim2.fromScale(1, 1),
                StrokeThickness = 1,
                BackgroundTransparency = 1,
                StrokeColor = Oktween(
                    scope, strokeColor,
                    TweenInfo.new(
                        .25, Enum.EasingStyle.Exponential, Enum.EasingDirection.InOut
                    )
                ),
                CornerRadius = Peek<<number>>(cornerRadius),
                StrokeTransparency = strokeTransparency
            }),

            New(scope, "UIFlexItem") {},
        },

        [Children] = {
            TransparencyGated(scope, NewImageLabel, {
                GatedTransparencyProperty = "ImageTransparency",
                Image = Assets.CheckboxTrue,
                ImageColor3 = accentFgColor,
                Size = UDim2.fromScale(1, 1),
                BackgroundTransparency = 1,
                ImageTransparency = checkedTransparency,

                Name = "CheckboxTrue"
            }),

            TransparencyGated(scope, NewImageLabel, {
                GatedTransparencyProperty = "ImageTransparency",
                Image = Assets.CheckboxMixed,
                ImageColor3 = accentFgColor,
                Size = UDim2.fromScale(1, 1),
                BackgroundTransparency = 1,
                ImageTransparency = mixedTransparency,

                Name = "CheckboxMixed"
            }),
        },

        Name = "Button"
    }, props)
end)
