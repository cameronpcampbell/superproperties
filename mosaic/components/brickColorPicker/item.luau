--!strict

local Packages = script.Parent.Parent.Parent.Parent

local Fusion = require(Packages.fusion)
local New, Children, Computed, Value, OnEvent =
    Fusion.New, Fusion.Children, Fusion.Computed,
    Fusion.Value, Fusion.OnEvent

local Utils = script.Parent.Parent.Parent.utils
local FusionUtils = require(Utils.fusionUtils)
local Oktween = FusionUtils.Oktween

local ThemeUtils = require(Utils.themeUtils)

local CoreComponents = script.Parent.Parent.Parent.coreComponents
local AdaptiveHighlight = require(CoreComponents.adaptiveHighlight)

local Assets = require(script.Parent.Parent.Parent.assets)

type BrickColorItemProps = {
    BrickColor: BrickColor,
    PaletteIndex: number,
    Size: UDim2,
    SelectedColor: Fusion.UsedAs<Color3?>,
    OnSelected: (color: Color3) -> ()
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
        return
            use<<Color3?>>(props.SelectedColor)
            == props.BrickColor.Color
    end)
    local adaptiveHighlightEnabled =
        Computed(scope, function(use): boolean
            return not use<<boolean>>(isSelected)
        end)
    local theme = ThemeUtils.GetThemeForScope(scope)
    local gradientColor =
        Computed(scope, function(use): ColorSequence?
            if not use<<boolean>>(isSelected) then return nil end

            local foregroundColor =
                ThemeUtils.GetBestColor(
                    props.BrickColor.Color,
                    use<<Color3>>(theme.FgPrimary),
                    use<<Color3>>(theme.AccentPrimary)
                )

            return ColorSequence.new(foregroundColor)
        end)
    local gradientTransparency =
        Computed(scope, function(use): number
            return if use<<boolean>>(isSelected) then 0 else 0.78
        end)
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
            props.OnSelected(props.BrickColor.Color)
        end,

        [Children] = {
            AdaptiveHighlight(scope, NewUnscoped("ImageLabel"), {
                Enabled = adaptiveHighlightEnabled,
                GradientColor = gradientColor,
                GradientTransparency = gradientTransparency,
                Size = UDim2.fromScale(1, 1),
                Image = Assets.BrickColorStroke,
                BackgroundTransparency = 1,
            })
        }
    }
end
