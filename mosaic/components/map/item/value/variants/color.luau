--!strict

local Packages =
    script.Parent.Parent.Parent.Parent.Parent.Parent.Parent.Parent.packages

local Fusion = require(Packages.fusion)
local New, Children, Peek = Fusion.New, Fusion.Children, Fusion.peek

local Utils = script.Parent.Parent.Parent.Parent.Parent.Parent.utils

local FusionUtils = require(Utils.fusionUtils)
local ComputeTransforms = FusionUtils.ComputeTransforms
local ComputeUDim2FromOffset = ComputeTransforms.UDim2FromOffset

local ThemeUtils = require(Utils.themeUtils)
local GetThemeForScope = ThemeUtils.GetThemeForScope

local Components = script.Parent.Parent.Parent.Parent.Parent
local HighlightGradient = require(Components.highlightGradient)
local Text = require(Components.text)

local Types = require(script.Parent.types)

local function Color(scope: Fusion.Scope, color: Color3 | BrickColor)
    if typeof(color) == "BrickColor" then
        color = color.Color
    end

    local theme = GetThemeForScope(scope)
    local height = theme:GetHeight(scope, "Sm")
    local cornerRadius = theme:GetCornerRadius(scope, "Sm")

    return HighlightGradient(scope, {
        GradientTransparency = 0.78,
        BackgroundColor3 = color :: Color3,
        StrokeThickness = 1,
        Size = ComputeUDim2FromOffset(scope, height, height),
        CornerRadius = Peek<<number>>(cornerRadius),
        CornerSmoothing = 1,
        LayoutOrder = 1,

        Name = "Color"
    })
end

return function(scope: Fusion.Scope, props: Types.ValueVariantProps<Color3 | BrickColor>)
    local value = props.Value

    return {
        Text(scope, {
            Text =
                if typeof(value) == "Color3" then
                    `[{math.round(value.G * 255)}, {math.round(value.G * 255)}, {math.round(value.G * 255)}]`
                else value.Name,
            Variant = if props.Writable then "Primary" else "Secondary",
            Size = UDim2.fromScale(1, 0),
            LayoutOrder = 0,

            [Children] = New(scope, "UIFlexItem") {
                FlexMode = Enum.UIFlexMode.Shrink
            }
        }),

        Color(scope, value),
    }
end
