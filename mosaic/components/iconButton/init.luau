--!strict
--!nolint LocalShadow

local Packages = script.Parent.Parent.Parent

local Fusion = require(Packages.fusion)
local Value, New, Children, OnEvent, Tween =
    Fusion.Value, Fusion.New, Fusion.Children,
    Fusion.OnEvent, Fusion.Tween

local Utils = script.Parent.Parent.utils

local FusionUtils = require(Utils.fusionUtils)
local Component, CombineProps = FusionUtils.Component, FusionUtils.CombineProps
local ComputeTransforms = FusionUtils.ComputeTransforms
local ComputeUDim2FromOffset = ComputeTransforms.UDim2FromOffset

local ThemeUtils = require(Utils.themeUtils)
local GetThemeForScope, CalcColorModifier =
    ThemeUtils.GetThemeForScope, ThemeUtils.CalcColorModifier

local TableUtils = require(Utils.tableUtils)
local TableExtract = TableUtils.Extract

type IconButtonProps = {
    Variant: ThemeUtils.FgVariant?,
    Rotation: Fusion.UsedAs<number>?,
    Image: Fusion.UsedAs<string>?,
    [Fusion.SpecialKey]: any
}

return Component<<IconButtonProps>>(function(scope, props)
    local props, variant = TableExtract(props, "Variant", "Primary")
    local props, rotation = TableExtract(props, "Rotation")
    local props, onClickEvent = TableExtract(props, OnEvent "MouseButton1Click")
    local props, image = TableExtract(props, "Image")

    local isHoverState, isFocusState = Value(scope, false), Value(scope, false)
    local themeColorModifier = CalcColorModifier(scope, isHoverState, isFocusState)

    local theme = GetThemeForScope(scope)
    local fgColor = theme:GetFg(scope, variant, themeColorModifier)
    local boundsHeight = theme:GetHeight(scope, "Lg")

    return New(scope, "Frame") (CombineProps({
        Size = UDim2.fromOffset(9, 9),
        BackgroundTransparency = 1,

        [Children] = {
            New(scope, "ImageLabel") {
                Image = image,
                Size = UDim2.fromOffset(9, 9),
                BackgroundTransparency = 1,
                ImageColor3 = Tween<<Color3>>(
                    scope, fgColor,
                    TweenInfo.new(
                        .25, Enum.EasingStyle.Exponential, Enum.EasingDirection.InOut
                    )
                ),
                Rotation = rotation
            },

            New(scope, "ImageButton") {
                Size = ComputeUDim2FromOffset(scope, boundsHeight, boundsHeight),
                BackgroundTransparency = 1,
                Position = UDim2.fromScale(.5, .5),
                AnchorPoint = Vector2.new(.5, .5),

                [OnEvent "MouseEnter"] = function() isHoverState:set(true) end,
                [OnEvent "MouseLeave"] = function() isHoverState:set(false) end,

                [OnEvent "MouseButton1Down"] = function() isFocusState:set(true) end,
                [OnEvent "MouseButton1Up"] = function() isFocusState:set(false) end,

                [OnEvent "MouseButton1Click"] = onClickEvent
            }
        }
    }, props))
end)
