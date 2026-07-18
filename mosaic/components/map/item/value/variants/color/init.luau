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
local HighlightSupercorner = require(Components.highlightSupercorner)
local Text = require(Components.text)

local Types = require(script.Parent.types)
local CreateSidePadding = require(script.Parent.utils.createSidePadding)
local CreateTextVariant = require(script.Parent.utils.createTextVariant)
local ParseColor = require(script.parser)

local function FormatColorComponents(color: Color3): string
    return
        `{math.round(color.R * 255)}, {math.round(color.G * 255)}, {math.round(color.B * 255)}`
end

local function FormatColor(color: Color3): string
    return `[{FormatColorComponents(color)}]`
end

local ColorTextVariant = CreateTextVariant<<Color3>>({
    InputName = "Color3ValueInput",
    Format = FormatColor,
    FormatFocused = FormatColorComponents,
    Parse = ParseColor
})

local function Color(scope: Fusion.Scope, color: Color3 | BrickColor)
    if typeof(color) == "BrickColor" then
        color = color.Color
    end

    local theme = GetThemeForScope(scope)
    local height = theme:GetHeight(scope, "Sm")
    local cornerRadius = theme:GetCornerRadius(scope, "Sm")

    return HighlightSupercorner(scope, {
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

return function(
    scope: Fusion.Scope,
    props: Types.ValueVariantProps<Color3 | BrickColor>
): Fusion.Child
    local value = props.Value

    if
        typeof(value) == "Color3" and
        props.Writable and
        props.TrySetValue ~= nil
    then
        return {
            ColorTextVariant(scope, {
                Value = value,
                Writable = props.Writable,
                TrySetValue = props.TrySetValue :: any,
                OnFocusChanged = props.OnFocusChanged
            }),

            Color(scope, value)
        } :: { Fusion.Child }
    end

    return {
        Text(scope, {
            Text =
                if typeof(value) == "Color3" then FormatColor(value) else value.Name,
            Variant = if props.Writable then "Primary" else "Secondary",
            Size = UDim2.fromScale(1, 0),

            [Children] = New(scope, "UIFlexItem") {
                FlexMode = Enum.UIFlexMode.Shrink
            }
        }),
        Color(scope, value),

        CreateSidePadding(scope)
    } :: { Fusion.Child }
end
