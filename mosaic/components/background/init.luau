--!strict
--!nolint LocalShadow

local Packages = script.Parent.Parent.Parent

local Fusion = require(Packages.fusion)
local New = Fusion.New

local Utils = script.Parent.Parent.utils

local FusionUtils = require(Utils.fusionUtils)
local Component, CombineProps =
    FusionUtils.Component, FusionUtils.CombineProps

local ThemeUtils = require(Utils.themeUtils)
local GetThemeForScope = ThemeUtils.GetThemeForScope

local TableUtils = require(Utils.tableUtils)
local TableExtract = TableUtils.Extract

type BackgroundProps = {
	Variant: ThemeUtils.BgVariant?
}

return Component<<BackgroundProps>>(function(scope, props)
    local props, variant = TableExtract(props, "Variant", "Primary")

    local theme = GetThemeForScope(scope)
    local bgColor = theme:GetBg(scope, variant)

    return New(scope, "Frame") (CombineProps({
        Name = "Background",

        BackgroundColor3 = bgColor,
        Size = UDim2.fromScale(1, 1)
    }, props))
end)
