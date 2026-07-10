--!strict
--!nolint LocalShadow

local Packages = script.Parent.Parent.Parent

local Fusion = require(Packages.fusion)
local Peek, New = Fusion.peek, Fusion.New

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
    local theme = Peek<<ThemeUtils.Theme>>(GetThemeForScope(scope))

    local props, variant = TableExtract(props, "Variant", "Primary")

    return New(scope, "Frame") (CombineProps({
        Name = "Background",

        BackgroundColor3 = theme:GetBg(scope, variant),
        Size = UDim2.fromScale(1, 1)
    }, props))
end)
