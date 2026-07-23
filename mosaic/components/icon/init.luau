--!strict
--!nolint LocalShadow

local Packages = script.Parent.Parent.Parent

local Fusion = require(Packages.fusion)
local New = Fusion.New

local Utils = script.Parent.Parent.utils

local FusionUtils = require(Utils.fusionUtils)
local Component, CombineProps = FusionUtils.Component, FusionUtils.CombineProps
local ComputeUDim2FromOffset =
    FusionUtils.ComputeTransforms.UDim2FromOffset

local ThemeUtils = require(Utils.themeUtils)
local GetThemeForScope = ThemeUtils.GetThemeForScope

local TableUtils = require(Utils.tableUtils)
local TableExtract = TableUtils.Extract

type IconButtonProps = {
    Variant: ThemeUtils.FgVariant?,
    Image: Fusion.UsedAs<string>?,
    Width: Fusion.UsedAs<number>?,
    [Fusion.SpecialKey | string]: any
}

local IconSize = 9

return Component<<IconButtonProps>>(function(scope, props)

    local props, variant = TableExtract(props, "Variant", "Primary")
    local props, image = TableExtract(props, "Image")
    local props, width = TableExtract(props, "Width", IconSize)

    local theme = GetThemeForScope(scope)
    local fgColor = theme:GetFg(scope, variant)

    return New(scope, "ImageLabel") (CombineProps({
        Image = image,
        Size = ComputeUDim2FromOffset(scope, width, IconSize),
        BackgroundTransparency = 1,
        ImageColor3 = fgColor
    }, props))
end)
