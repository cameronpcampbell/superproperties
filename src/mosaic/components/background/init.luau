--!strict
--!nolint LocalShadow

local Packages = script.Parent.Parent.Parent.packages
local Fusion = require(Packages.fusion)

local Utils = script.Parent.Parent.utils
local FusionUtils = require(Utils.fusionUtils)
local TableUtils = require(Utils.tableUtils)
local ThemeUtils = require(Utils.themeUtils)

local Peek, New = Fusion.peek, Fusion.New
local Component, CombineProps =
    FusionUtils.Component, FusionUtils.CombineProps
local TableExtract = TableUtils.Extract
local GetThemeForScope = ThemeUtils.GetThemeForScope

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
