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

local Assets = require(script.Parent.Parent.assets)

type CheckboxProps = {
    Checked: Fusion.UsedAs<boolean>?,
    Disabled: Fusion.UsedAs<boolean>?
}

return Component<<CheckboxProps>>(function(scope, props)

    local props, checked = TableExtract(props, "Checked", true)
    local props, disabled = TableExtract(props, "Disabled", true)

    local checkedState = CoerceToValue<<boolean>>(scope, checked)

    local isHoverState, isFocusState = Value(scope, false), Value(scope, false)
    local themeColorModifier = CalcColorModifier(scope, isHoverState, isFocusState)

    local computeTruthyTransparency = Tween<<number>>(
        scope,
        Computed(scope, function(use, scope)
            return if use<<boolean>>(checkedState) then 0 else 1
        end),
        TweenInfo.new(
            .25, Enum.EasingStyle.Exponential, Enum.EasingDirection.InOut
        )
    )

    local theme = GetThemeForScope(scope)
    local accentColor = theme:GetAccent(scope, "Primary", themeColorModifier)
    local fgColor = theme:GetFg(scope, "Primary", themeColorModifier)
    local highlightGradient = theme:HighlightGradient(scope, 0.78)
    local height = theme:GetHeight(scope, "Sm")
    local cornerRadius = theme:GetCornerRadius(scope, "Sm")

    return Supercorner.new(scope, CombineProps({
        Button = true,
        BackgroundColor3 = Tween<<Color3>>(
            scope, accentColor,
            TweenInfo.new(
                .25, Enum.EasingStyle.Exponential, Enum.EasingDirection.InOut
            )
        ),
        BackgroundTransparency = computeTruthyTransparency,
        StrokeTransparency = computeTruthyTransparency,
        StrokeGradient = highlightGradient,
        StrokeThickness = 1,
        Size = ComputeUDim2FromOffset(scope, height, height),
        CornerRadius = cornerRadius,
        CornerSmoothing = 1,

        [OnEvent "MouseEnter"] = function()
            --if Peek<<boolean>>(disabled) then return end

            isHoverState:set(true)
        end,

        [OnEvent "MouseLeave"] = function()
            --if Peek<<boolean>>(disabled) then return end

            isHoverState:set(false)
        end,

        [OnEvent "MouseButton1Down"] = function()
            --if Peek<<boolean>>(disabled) then return end

            isFocusState:set(true)
        end,

        [OnEvent "MouseButton1Up"] = function()
            --if Peek<<boolean>>(disabled) then return end

            isFocusState:set(false)
        end,

        [OnEvent "MouseButton1Click"] = function()
            if Peek<<boolean>>(disabled) then return end

            checkedState:set(not Peek<<boolean>>(checkedState))
        end,

        RootChildren = {
            Supercorner.new(scope, {
                Size = UDim2.fromScale(1, 1),
                StrokeThickness = 1,
                BackgroundTransparency = 1,
                StrokeColor = Tween<<Color3>>(
                    scope, fgColor,
                    TweenInfo.new(
                        .25, Enum.EasingStyle.Exponential, Enum.EasingDirection.InOut
                    )
                ),
                CornerRadius = cornerRadius,
                StrokeTransparency = Tween<<number>>(
                    scope,
                    Computed(scope, function(use: any, scope)
                        return if use(checkedState) then 1 else 0
                    end),
                    TweenInfo.new(
                        .25, Enum.EasingStyle.Exponential, Enum.EasingDirection.InOut
                    )
                )
            }),

            New(scope, "UIFlexItem") {},
        },

        [Children] = {
            New(scope, "ImageLabel") {
                Image = Assets.CheckboxTrue,
                ImageColor3 = fgColor,
                Size = UDim2.fromScale(1, 1),
                BackgroundTransparency = 1,
                ImageTransparency = computeTruthyTransparency
            },
        },

        Name = "Button"
    }, props))
end)
