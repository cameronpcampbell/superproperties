--!strict
--!nolint LocalShadow

local Packages = script.Parent.Parent.Parent
local Supercorner = require(Packages.supercorner)

local Fusion = require(Packages.fusion)
local Peek = Fusion.peek

local Utils = script.Parent.Parent.utils

local FusionUtils = require(Utils.fusionUtils)
local Component, CombineProps =
    FusionUtils.Component, FusionUtils.CombineProps

local ThemeUtils = require(Utils.themeUtils)
local GetThemeForScope, GetNextVariant =
    ThemeUtils.GetThemeForScope, ThemeUtils.GetNextVariant

local TableUtils = require(Utils.tableUtils)
local TableExtract = TableUtils.Extract

type ContainerProps = {
	Variant: ThemeUtils.BgVariantLayer?,
	CornerRadius: ThemeUtils.CornerRadiusVariant?
}

return Component<<ContainerProps>>(function(scope, props)
    local props, variant = TableExtract(props, "Variant", "Primary")
    local props, cornerRadiusVariant =
        TableExtract(props, "CornerRadius", "Md")

    local theme = GetThemeForScope(scope)
    local bgColor = theme:GetBg(scope, variant)
    local strokeColor = theme:GetBg(scope, GetNextVariant(scope, variant))
    local cornerRadius = theme:GetCornerRadius(scope, cornerRadiusVariant)

    return Supercorner.new(scope, CombineProps({
        Name = "Container",

        BackgroundColor3 = bgColor,
        StrokeColor = strokeColor,
        StrokeThickness = 1,
        Size = UDim2.fromScale(1, 1),
        CornerRadius = Peek<<number>>(cornerRadius),
        CornerSmoothing = 1
    }, props))
end)
