--!strict

local Packages = script.Parent.Parent.Parent.Parent

local Fusion = require(Packages.fusion)
local New, Children, Computed, Value, OnEvent, Tween =
    Fusion.New, Fusion.Children, Fusion.Computed,
    Fusion.Value, Fusion.OnEvent, Fusion.Tween

local Utils = script.Parent.Parent.Parent.utils
local FusionUtils = require(Utils.fusionUtils)
local ComposeTransparency, Oktween =
    FusionUtils.ComposeTransparency, FusionUtils.Oktween

local ColorSpace = require(Utils.colorSpace)
local ThemeUtils = require(Utils.themeUtils)

local CoreComponents = script.Parent.Parent.Parent.coreComponents
local AdaptiveHighlight = require(CoreComponents.adaptiveHighlight)
local TransparencyGated = require(CoreComponents.transparencyGated)

local Assets = require(script.Parent.Parent.Parent.assets)

local SelectionTransparencyTweenInfo = TweenInfo.new(
    .18,
    Enum.EasingStyle.Exponential,
    Enum.EasingDirection.InOut
)

type BrickColorItemProps = {
    BrickColor: BrickColor,
    PaletteIndex: number,
    Size: UDim2,
    SelectedBrickColor: Fusion.UsedAs<BrickColor?>,
    OnSelected: (brickColor: BrickColor) -> (),
    Transparency: Fusion.UsedAs<number>
}

local function NewUnscoped(name: string)
    return function(
        scope: Fusion.Scope,
        props: { [any]: any }
    ): Fusion.Child
        return New(scope, name)(props)
    end
end

return function(
    scope: Fusion.Scope,
    props: BrickColorItemProps
): Fusion.Child
    local isHoverState, isFocusState = Value(scope, false), Value(scope, false)
    local isSelected = Computed(scope, function(use): boolean
        local selectedBrickColor =
            use<<BrickColor?>>(props.SelectedBrickColor)

        return selectedBrickColor ~= nil
            and selectedBrickColor.Number == props.BrickColor.Number
    end)

    local adaptiveHighlightEnabled =
        Computed(scope, function(use): boolean
            return not use<<boolean>>(isSelected)
        end)

    local theme = ThemeUtils.GetThemeForScope(scope)

    local selectionColor = Computed(scope, function(use): Color3
        return ColorSpace.Srgb.From(
            ColorSpace.Srgb.From(props.BrickColor.Color):BestContrast(
                ColorSpace.Srgb.From(use<<Color3>>(theme.FgPrimary)),
                ColorSpace.Srgb.From(use<<Color3>>(theme.AccentPrimary)),
                ColorSpace.Srgb.From(use<<Color3>>(theme.AccentFgPrimary))
            )
        ):ToColor3()
    end)

    local gradientColor =
        Computed(scope, function(use): ColorSequence?
            if not use<<boolean>>(isSelected) then return nil end

            return ColorSequence.new(use<<Color3>>(selectionColor))
        end)

    local gradientTransparency =
        Computed(scope, function(use): number
            return if use<<boolean>>(isSelected) then 0 else 0.78
        end)
    local composedGradientTransparency = ComposeTransparency(
        scope,
        gradientTransparency,
        props.Transparency
    )
    local imageTransparency = ComposeTransparency(
        scope,
        0,
        props.Transparency
    )

    local selectionTransparency = Tween<<number>>(
        scope,
        Computed(scope, function(use): number
            return if use<<boolean>>(isSelected) then 0 else 1
        end),
        SelectionTransparencyTweenInfo
    )
    local composedSelectionTransparency = ComposeTransparency(
        scope,
        selectionTransparency,
        props.Transparency
    )

    local colorModifier = ThemeUtils.CalcColorModifier(
        scope,
        isHoverState,
        isFocusState
    )

    local imageColor = Oktween(
        scope,
        ThemeUtils.ApplyColorModifier(
            scope,
            props.BrickColor.Color,
            colorModifier
        ),
        TweenInfo.new(
            .18,
            Enum.EasingStyle.Exponential,
            Enum.EasingDirection.InOut
        )
    )

    return New(scope, "ImageButton") {
        Size = props.Size,
        LayoutOrder = props.PaletteIndex,
        Image = Assets.BrickColor,
        ImageColor3 = imageColor,
        ImageTransparency = imageTransparency,
        BackgroundTransparency = 1,
        Name = props.BrickColor.Name,

        [OnEvent "MouseEnter"] = function()
            isHoverState:set(true)
        end,

        [OnEvent "MouseLeave"] = function()
            isHoverState:set(false)
            isFocusState:set(false)
        end,

        [OnEvent "MouseButton1Down"] = function()
            isFocusState:set(true)
        end,

        [OnEvent "MouseButton1Up"] = function()
            isFocusState:set(false)
        end,

        [OnEvent "MouseButton1Click"] = function()
            props.OnSelected(props.BrickColor)
        end,

        [Children] = {
            AdaptiveHighlight(scope, NewUnscoped("ImageLabel"), {
                Enabled = adaptiveHighlightEnabled,
                GradientColor = gradientColor,
                GradientTransparency = composedGradientTransparency,
                Size = UDim2.fromScale(1, 1),
                Image = Assets.BrickColorStroke,
                BackgroundTransparency = 1,
            }),

            TransparencyGated(scope, NewUnscoped("ImageLabel"), {
                GatedTransparencyProperty = "ImageTransparency",
                Size = UDim2.fromScale(1, 1),
                Image = Assets.BrickColorCheck,
                ImageColor3 = selectionColor,
                ImageTransparency = composedSelectionTransparency,
                BackgroundTransparency = 1,
                ZIndex = 2,

                Name = "BrickColorCheck"
            })
        }
    }
end
