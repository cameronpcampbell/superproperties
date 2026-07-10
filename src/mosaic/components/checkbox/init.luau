--!strict
--!nolint LocalShadow

local Packages = script.Parent.Parent.Parent.packages
local Supercorner = require(Packages.supercorner)

local Fusion = require(Packages.fusion)
local New, Children, Value, Peek, Computed, OnEvent, Tween =
    Fusion.New, Fusion.Children, Fusion.Value, Fusion.peek,
    Fusion.Computed, Fusion.OnEvent, Fusion.Tween

local Utils = script.Parent.Parent.utils

local FusionUtils = require(Utils.fusionUtils)
local Component, CombineProps, CoerceToValue =
    FusionUtils.Component, FusionUtils.CombineProps, FusionUtils.CoerceToValue

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
    local theme = Peek<<ThemeUtils.Theme>>(GetThemeForScope(scope))

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

    return Supercorner.new(scope, CombineProps({
        Button = true,
        BackgroundColor3 = Tween<<Color3>>(
            scope,
            theme:GetAccent(scope, "Primary", themeColorModifier),
            TweenInfo.new(
                .25, Enum.EasingStyle.Exponential, Enum.EasingDirection.InOut
            )
        ),
        BackgroundTransparency = computeTruthyTransparency,
        StrokeTransparency = computeTruthyTransparency,
        StrokeGradient = theme:HighlightGradient(scope, 0.78),
        StrokeThickness = 1,
        Size = UDim2.fromOffset(theme:GetHeight("Sm"), theme:GetHeight("Sm")),
        CornerRadius = theme:GetCornerRadius("Sm"),
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
                    scope,
                    theme:GetFg(scope, "Primary", themeColorModifier),
                    TweenInfo.new(
                        .25, Enum.EasingStyle.Exponential, Enum.EasingDirection.InOut
                    )
                ),
                CornerRadius = theme:GetCornerRadius("Sm"),
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
                ImageColor3 = theme:GetFg(scope, "Primary"),
                Size = UDim2.fromScale(1, 1),
                BackgroundTransparency = 1,
                ImageTransparency = computeTruthyTransparency
            },
        },

        Name = "Button"
    }, props))
end)
