--!strict
--!nolint LocalShadow

local Packages = script.Parent.Parent.Parent
local Supercorner = require(Packages.supercorner)

local Fusion = require(Packages.fusion)
local New, Children, Value, Peek =
    Fusion.New, Fusion.Children, Fusion.Value, Fusion.peek

local Utils = script.Parent.Parent.utils

local FusionUtils = require(Utils.fusionUtils)
local Component, CombineProps =
    FusionUtils.Component, FusionUtils.CombineProps
local ComputeTransforms = FusionUtils.ComputeTransforms
local ComputeUDim2, ComputeUDim = ComputeTransforms.UDim2, ComputeTransforms.UDim

local ThemeUtils = require(Utils.themeUtils)
local GetThemeForScope, GetNextVariant, CalcColorModifier =
    ThemeUtils.GetThemeForScope, ThemeUtils.GetNextVariant,
    ThemeUtils.CalcColorModifier

local TableUtils = require(Utils.tableUtils)
local TableExtract = TableUtils.Extract

local Components = script.Parent.Parent.components
local Scrollable = require(Components.scrollable)

local SelectMenuItem = require(script.item)

type SelectMenuProps = {
	Variant: ThemeUtils.BgVariantSubLayer?,
	Width: UDim?
}

return Component<<SelectMenuProps>>(function(scope, props)
    local props, variant = TableExtract(props, "Variant", "Tertiary")
    local props, width = TableExtract(props, "Width", UDim.new(1, 0))

    local isHoverState, isFocusState = Value(scope, false), Value(scope, false)
    local themeColorModifier =
        CalcColorModifier(scope, isHoverState, isFocusState, "Stroke")

    local theme = GetThemeForScope(scope)
    local bgColor = theme:GetBg(scope, variant)
    local strokeColor =
        theme:GetBg(scope, GetNextVariant(scope, variant), themeColorModifier)
    local cornerRadius = theme:GetCornerRadius(scope, "Md")

    return Supercorner.new(scope :: any, CombineProps({
        BackgroundColor3 = bgColor,
        StrokeColor = strokeColor,
        StrokeThickness = 1,
        Size = ComputeUDim2(scope, width, ComputeUDim(scope, 0, 250)),
        CornerRadius = Peek<<number>>(cornerRadius),
        CornerSmoothing = 1,

        Name = "SelectMenu",

        RootChildren = {
            New(scope, "UIFlexItem") {},
        },

        [Children] = {
            Scrollable(scope, {
                Variant = GetNextVariant(scope, variant),

                [Children] = {

                }
            }),

            New(scope, "UIPadding") {
                PaddingLeft = UDim.new(0, 4),
                PaddingRight = UDim.new(0, 4),
                PaddingTop = UDim.new(0, 4),
                PaddingBottom = UDim.new(0, 4),
            }
        }
    }, props))
end)
