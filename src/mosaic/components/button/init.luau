--!strict
--!nolint LocalShadow

local Packages = script.Parent.Parent.Parent.packages
local Supercorner = require(Packages.supercorner)

local Fusion = require(Packages.fusion)
local New, Children, Value, Peek, OnEvent, Tween =
    Fusion.New, Fusion.Children, Fusion.Value,
    Fusion.peek, Fusion.OnEvent, Fusion.Tween

local Utils = script.Parent.Parent.utils

local FusionUtils = require(Utils.fusionUtils)
local Component, CombineProps, ChildrenTransform =
    FusionUtils.Component, FusionUtils.CombineProps, FusionUtils.ChildrenTransform

local ThemeUtils = require(Utils.themeUtils)
local GetThemeForScope, CalcColorModifier =
    ThemeUtils.GetThemeForScope, ThemeUtils.CalcColorModifier

local TableUtils = require(Utils.tableUtils)
local TableExtract = TableUtils.Extract

local Components = script.Parent
local Text = require(Components.text)

type ButtonProps = {
	Variant: ThemeUtils.AccentVariant?,
	Width: UDim?
}

local function TransformChild(scope: Fusion.Scope, child: unknown): Fusion.Child?
    local childTypeof = typeof(child)

    if childTypeof ~= "string" then
        return if childTypeof == "Instance" then child :: Fusion.Child else nil

    elseif string.match(child :: string, "^rbxassetid://%d+$") then
        local theme = Peek<<ThemeUtils.Theme>>(GetThemeForScope(scope))

        return New (scope, "ImageLabel") {
            Size = UDim2.fromOffset(9, 9),
            BackgroundTransparency = 1,
            ImageColor3 = theme:GetFg(scope, "Primary"),
            Image = child
        }

    else
        return Text (scope, {
            Text = child :: string,
        })

    end
end

return Component<<ButtonProps>>(function(scope, props)
    local theme = Peek<<ThemeUtils.Theme>>(GetThemeForScope(scope))

    local props, variant = TableExtract(props, "Variant", "Primary")
    local props, width = TableExtract(props, "Width", UDim.new(1, 0))
    local props, children = TableExtract(props, Children)

    local isHoverState, isFocusState = Value(scope, false), Value(scope, false)
    local themeColorModifier = CalcColorModifier(scope, isHoverState, isFocusState)

    return Supercorner.new(scope :: any, CombineProps({
        Button = true,
        BackgroundColor3 = Tween<<Color3>>(
            scope,
            theme:GetAccent(scope, variant, themeColorModifier),
            TweenInfo.new(
                .25, Enum.EasingStyle.Exponential, Enum.EasingDirection.InOut
            )
        ),
        StrokeGradient = theme:HighlightGradient(scope, 0.78),
        StrokeThickness = 1,
        Size = UDim2.new(width, UDim.new(0, theme:GetHeight("Lg"))),
        CornerRadius = theme:GetCornerRadius("Md"),
        CornerSmoothing = 1,

        [OnEvent "MouseEnter"] = function() isHoverState:set(true) end,
        [OnEvent "MouseLeave"] = function() isHoverState:set(false) end,

        [OnEvent "MouseButton1Down"] = function() isFocusState:set(true) end,
        [OnEvent "MouseButton1Up"] = function() isFocusState:set(false) end,

        RootChildren = New(scope, "UIFlexItem") {},

        [Children] = {
            ChildrenTransform(scope, TransformChild, children),

            New(scope, "UIListLayout") {
                FillDirection = Enum.FillDirection.Horizontal,
                HorizontalAlignment = Enum.HorizontalAlignment.Center,
                VerticalAlignment = Enum.VerticalAlignment.Center,
                Padding = UDim.new(0, 6)
            }
        },

        Name = "Button"
    }, props))
end)
