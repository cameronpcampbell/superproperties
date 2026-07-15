--!strict

local Packages =
    script.Parent.Parent.Parent.Parent.Parent.Parent.Parent.Parent.packages
local Supercorner = require(Packages.supercorner)

local Fusion = require(Packages.fusion)
local New, Children, Peek = Fusion.New, Fusion.Children, Fusion.peek

local Utils = script.Parent.Parent.Parent.Parent.Parent.Parent.utils

local FusionUtils = require(Utils.fusionUtils)
local ComputeTransforms = FusionUtils.ComputeTransforms
local ComputeUDim2FromOffset = ComputeTransforms.UDim2FromOffset

local ThemeUtils = require(Utils.themeUtils)
local GetThemeForScope = ThemeUtils.GetThemeForScope

local Components = script.Parent.Parent.Parent.Parent.Parent
local Text = require(Components.text)

local Types = require(script.Parent.types)

local function Color(scope: Fusion.Scope, color: Color3 | BrickColor)
    if typeof(color) == "BrickColor" then
        color = color.Color
    end

    local theme = GetThemeForScope(scope)
    local highlightGradient = theme:HighlightGradient(scope, 0.78)
    local height = theme:GetHeight(scope, "Sm")
    local cornerRadius = theme:GetCornerRadius(scope, "Sm")

    return Supercorner.new(scope, {
        BackgroundColor3 = color :: Color3,
        StrokeGradient = highlightGradient,
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

    return New(scope, "Frame") {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,

        [Children] = {
            Text(scope, {
                Text = tostring(value),
                Variant = "Primary",
                Size = UDim2.fromScale(1, 0),
                LayoutOrder = 0,

                [Children] = New(scope, "UIFlexItem") {
                    FlexMode = Enum.UIFlexMode.Shrink
                }
            }),

            Color(scope, value),

            New(scope, "UIListLayout") {
                Padding = UDim.new(0, 6),
                FillDirection = Enum.FillDirection.Horizontal,
                HorizontalFlex = Enum.UIFlexAlignment.SpaceBetween,
                VerticalAlignment = Enum.VerticalAlignment.Center,
                SortOrder = Enum.SortOrder.LayoutOrder
            },
        }
    }
end
