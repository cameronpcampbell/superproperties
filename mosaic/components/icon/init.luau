--!strict
--!nolint LocalShadow

local Packages = script.Parent.Parent.Parent

local Fusion = require(Packages.fusion)
local Peek, New = Fusion.peek, Fusion.New

local Utils = script.Parent.Parent.utils

local FusionUtils = require(Utils.fusionUtils)
local Component, CombineProps = FusionUtils.Component, FusionUtils.CombineProps

local ThemeUtils = require(Utils.themeUtils)
local GetThemeForScope = ThemeUtils.GetThemeForScope

local TableUtils = require(Utils.tableUtils)
local TableExtract = TableUtils.Extract

type IconButtonProps = {
    Variant: ThemeUtils.FgVariant?,
    Image: Fusion.UsedAs<string>?,
    [Fusion.SpecialKey]: any
}

return Component<<IconButtonProps>>(function(scope, props)
    local theme = Peek<<ThemeUtils.Theme>>(GetThemeForScope(scope))

    local props, variant = TableExtract(props, "Variant", "Primary")
    local props, image = TableExtract(props, "Image")

    return New(scope, "ImageLabel") (CombineProps({
        Image = image,
        Size = UDim2.fromOffset(9, 9),
        BackgroundTransparency = 1,
        ImageColor3 = theme:GetFg(scope, variant)
    }, props))
end)
