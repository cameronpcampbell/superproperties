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

type TextProps = {
    Text: string,
    Variant: ThemeUtils.FgVariant?,
	Font: ThemeUtils.FontVariant?,
	FontWeight: Enum.FontWeight?,
	FontStyle: Enum.FontStyle?,
	FontSize: ThemeUtils.FontSizeVariant?,
}

return Component<<TextProps>>(function(scope, props)
    local theme = Peek<<ThemeUtils.Theme>>(GetThemeForScope(scope))

    local props, text = TableExtract(props, "Text")
    local props, variant = TableExtract(props, "Variant", "Primary")
    local props, font = TableExtract(props, "Font", "Main")
    local props, fontWeight = TableExtract(props, "FontWeight", Enum.FontWeight.Regular)
    local props, fontStyle = TableExtract(props, "FontStyle", Enum.FontStyle.Normal)
    local props, fontSize = TableExtract(props, "FontSize", "Body")

    return New (scope, "TextLabel") (CombineProps({
        Text = text,
        TextColor3 = theme:GetFg(scope, variant),
        FontFace = theme:GetFont(font, fontWeight, fontStyle),
        TextSize = theme:GetFontSize(font, fontSize),
        Size = UDim2.fromScale(0, 0),
        AutomaticSize = Enum.AutomaticSize.XY,
        BackgroundTransparency = 1,
        TextTruncate = Enum.TextTruncate.AtEnd,
        TextXAlignment = Enum.TextXAlignment.Left,

        Name = "Text"
    }, props))
end)
