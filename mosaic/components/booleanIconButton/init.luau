--!strict
--!nolint LocalShadow

local Packages = script.Parent.Parent.Parent

local Fusion = require(Packages.fusion)
local Children, Computed, New, OnEvent, Peek, Tween, Value =
    Fusion.Children, Fusion.Computed, Fusion.New, Fusion.OnEvent,
    Fusion.peek, Fusion.Tween, Fusion.Value

local Utils = script.Parent.Parent.utils

local FusionUtils = require(Utils.fusionUtils)
local CombineProps, Component, CoerceToValue, ComposeTransparency, Oktween =
    FusionUtils.CombineProps, FusionUtils.Component, FusionUtils.CoerceToValue,
    FusionUtils.ComposeTransparency, FusionUtils.Oktween
local ComputeUDim2FromOffset =
    FusionUtils.ComputeTransforms.UDim2FromOffset

local ThemeUtils = require(Utils.themeUtils)
local GetThemeForScope, CalcColorModifier =
    ThemeUtils.GetThemeForScope, ThemeUtils.CalcColorModifier

local TableUtils = require(Utils.tableUtils)
local TableExtract = TableUtils.Extract

local CoreComponents = script.Parent.Parent.coreComponents
local CoreButton = require(CoreComponents.button)
local TransparencyGated = require(CoreComponents.transparencyGated)

type BooleanIconButtonProps = {
    Value: Fusion.UsedAs<boolean>?,
    TruthyIcon: Fusion.UsedAs<string>,
    FalseyIcon: Fusion.UsedAs<string>,
    Variant: ThemeUtils.FgVariant?,
    Rotation: Fusion.UsedAs<number>?,
    ImageColor3: Fusion.UsedAs<Color3>?,
    Transparency: Fusion.UsedAs<number>?,
    Disabled: Fusion.UsedAs<boolean>?,
    ZIndex: Fusion.UsedAs<number>?,
    LayoutOrder: number?,
    OnChanged: ((value: boolean) -> ())?,
    [Fusion.SpecialKey | string]: any
}

local DisabledTransparency = 0.5
local ImageTweenInfo = TweenInfo.new(
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

local function NewImageButton(
    scope: Fusion.Scope,
    props: { [any]: any }
): Fusion.Child
    return New(scope, "ImageButton")(props)
end

return Component<<BooleanIconButtonProps>>(function(scope, props)
    local props, value = TableExtract(props, "Value", false)
    local props, truthyIcon = TableExtract(props, "TruthyIcon")
    local props, falseyIcon = TableExtract(props, "FalseyIcon")
    local props, variant = TableExtract(props, "Variant", "Primary")
    local props, rotation = TableExtract(props, "Rotation")
    local props, imageColor = TableExtract(props, "ImageColor3")
    local props, transparency =
        TableExtract(props, "Transparency", 0)
    local props, disabled = TableExtract(props, "Disabled", false)
    local props, zIndex = TableExtract(props, "ZIndex", 1)
    local props, onChanged = TableExtract(props, "OnChanged")
    local props, onClickEvent =
        TableExtract(props, OnEvent "MouseButton1Click")
    local props, onActivatedEvent =
        TableExtract(props, OnEvent "Activated")

    local valueState = CoerceToValue<<boolean>>(scope, value)
    local isHoverState, isFocusState =
        Value(scope, false), Value(scope, false)
    local themeColorModifier =
        CalcColorModifier(scope, isHoverState, isFocusState)

    local interactable = Computed(scope, function(use): boolean
        return not use<<boolean>>(disabled)
    end)
    local disabledTransparency = Computed(scope, function(use): number
        return
            if use<<boolean>>(disabled)
            then DisabledTransparency
            else 0
    end)
    local baseImageTransparency = ComposeTransparency(
        scope,
        transparency,
        disabledTransparency
    )
    local truthyVisibilityTransparency = Tween<<number>>(
        scope,
        Computed(scope, function(use): number
            return
                if use<<boolean>>(valueState)
                then 0
                else 1
        end),
        ImageTweenInfo
    )
    local falseyVisibilityTransparency = Tween<<number>>(
        scope,
        Computed(scope, function(use): number
            return
                if use<<boolean>>(valueState)
                then 1
                else 0
        end),
        ImageTweenInfo
    )
    local truthyTransparency = ComposeTransparency(
        scope,
        baseImageTransparency,
        truthyVisibilityTransparency
    )
    local falseyTransparency = ComposeTransparency(
        scope,
        baseImageTransparency,
        falseyVisibilityTransparency
    )

    local theme = GetThemeForScope(scope)
    local fgColor =
        imageColor or theme:GetFg(scope, variant, nil, themeColorModifier)
    local animatedFgColor = Oktween(
        scope,
        fgColor,
        TweenInfo.new(
            0.25,
            Enum.EasingStyle.Exponential,
            Enum.EasingDirection.InOut
        )
    )
    local boundsHeight = theme:GetHeight(scope, "Lg")

    local function ToggleValue()
        if Peek<<boolean>>(disabled) then return end

        local nextValue = not Peek<<boolean>>(valueState)
        if onChanged then
            onChanged(nextValue)
            return
        end

        valueState:set(nextValue)
    end

    return New(scope, "Frame")(CombineProps({
        Size = UDim2.fromOffset(9, 9),
        BackgroundTransparency = 1,
        Interactable = interactable,
        ZIndex = zIndex,

        [Children] = {
            TransparencyGated(scope, NewImageLabel, {
                GatedTransparencyProperty = "ImageTransparency",
                Image = truthyIcon,
                Size = UDim2.fromOffset(9, 9),
                BackgroundTransparency = 1,
                ImageTransparency = truthyTransparency,
                ImageColor3 = animatedFgColor,
                Rotation = rotation,
                ZIndex = zIndex,

                Name = "TruthyIcon"
            }),

            TransparencyGated(scope, NewImageLabel, {
                GatedTransparencyProperty = "ImageTransparency",
                Image = falseyIcon,
                Size = UDim2.fromOffset(9, 9),
                BackgroundTransparency = 1,
                ImageTransparency = falseyTransparency,
                ImageColor3 = animatedFgColor,
                Rotation = rotation,
                ZIndex = zIndex,

                Name = "FalseyIcon"
            }),

            CoreButton(scope, NewImageButton, {
                Size = ComputeUDim2FromOffset(
                    scope,
                    boundsHeight,
                    boundsHeight
                ),
                BackgroundTransparency = 1,
                Position = UDim2.fromScale(0.5, 0.5),
                AnchorPoint = Vector2.new(0.5, 0.5),
                Interactable = interactable,
                ZIndex = zIndex,

                [OnEvent "MouseEnter"] = function()
                    isHoverState:set(true)
                end,

                [OnEvent "MouseLeave"] = function()
                    isHoverState:set(false)
                end,

                [OnEvent "MouseButton1Down"] = function()
                    isFocusState:set(true)
                end,

                [OnEvent "MouseButton1Up"] = function()
                    isFocusState:set(false)
                end,

                [OnEvent "Activated"] = onActivatedEvent,
                [OnEvent "MouseButton1Click"] =
                    onClickEvent or ToggleValue
            }) :: Instance
        },

        Name = "BooleanIconButton"
    }, props))
end)
