--!strict

local Packages = script.Parent.Parent.Parent.Parent
local Fusion = require(Packages.fusion)

local Utils = script.Parent.Parent
local ColorSpace = require(Utils.colorSpace)

local Types = require(script.Parent.types)

local New = Fusion.New

local function ApplyHoverColorModifier(theme: Types.Theme, color: Color3)
    return
        ColorSpace.Oklab.From(color)
            :Lerp(ColorSpace.Oklab.From(theme.BgPrimary), .1)
            :ToColor3()
end

local function ApplyHoverStrokeColorModifier(theme: Types.Theme, color: Color3)
    return
        ColorSpace.Oklab.From(color)
            :Lerp(ColorSpace.Oklab.From(theme.FgPrimary), .1)
            :ToColor3()
end

local function ApplyPressColorModifier(theme: Types.Theme, color: Color3)
    return ColorSpace.Oklab.From(color)
        :Lerp(ColorSpace.Oklab.From(theme.BgPrimary), .2)
        :ToColor3()
end

local function ApplyColorModifier(
    theme: Types.Theme,
    scope: Fusion.Scope,
    color: Color3,
    modifier: Fusion.UsedAs<Types.ThemeColorModifier?>
): Fusion.Computed<Color3>
    return Fusion.Computed(scope, function(use, scope): Color3
        local usedModifier = use(modifier)

        return
            if usedModifier == "Hover" then ApplyHoverColorModifier(theme, color)
            elseif usedModifier == "HoverStroke" then ApplyHoverStrokeColorModifier(theme, color)
            elseif usedModifier == "Press" then ApplyPressColorModifier(theme, color)
            else color
    end)
end

local function GetBg(
    theme: Types.Theme,
    scope: Fusion.Scope,
    variant: Types.BgVariant,
    modifier: Fusion.UsedAs<Types.ThemeColorModifier?>
): Fusion.Computed<Color3>
    local color = (theme :: any)[`Bg{variant}`] or theme.BgPrimary
    return ApplyColorModifier(theme, scope, color, modifier)
end

local function GetBgHighlight(
    theme: Types.Theme,
    scope: Fusion.Scope,
    variant: Types.BgVariantLayer,
    modifier: Fusion.UsedAs<Types.ThemeColorModifier?>
): Fusion.Computed<Color3>
    local color = (theme :: any)[`Bg{variant}Highlight`] or theme.BgPrimaryHighlight
    return ApplyColorModifier(theme, scope, color, modifier)
end

local function GetFg(
    theme: Types.Theme,
    scope: Fusion.Scope,
    variant: Types.FgVariant,
    modifier: Fusion.UsedAs<Types.ThemeColorModifier?>
): Fusion.Computed<Color3>
    local color = (theme :: any)[`Fg{variant}`] or theme.FgPrimary
    return ApplyColorModifier(theme, scope, color, modifier)
end

local function GetAccent(
    theme: Types.Theme,
    scope: Fusion.Scope,
    variant: Types.AccentVariant,
    modifier: Fusion.UsedAs<Types.ThemeColorModifier?>
): Fusion.Computed<Color3>
    local color = (theme :: any)[`Accent{variant}`] or theme.AccentPrimary
    return ApplyColorModifier(theme, scope, color, modifier)
end

local function GetHeight(theme: Types.Theme, variant: Types.HeightVariant): number
    return (theme :: any)[`Height{variant}`] or theme.HeightMd
end

local function GetCornerRadius(
    theme: Types.Theme,
    variant: Types.CornerRadiusVariant
): number
    return (theme :: any)[`CornerRadius{variant}`] or theme.CornerRadiusMd
end

local function GetFont(
    theme: Types.Theme,
    variant: Types.FontVariant,
    weight: Enum.FontWeight?,
    style: Enum.FontStyle?
): Font
    local font = ((theme :: any)[`Font{variant}`] or theme.FontMain) :: Font
    font.Weight = weight or Enum.FontWeight.Medium
    font.Style = style or Enum.FontStyle.Normal

    return font
end

local function GetFontSize(
    theme: Types.Theme,
    variant: Types.FontVariant,
    sizeVariant: Types.FontSizeVariant
): number
    return (theme :: any)[`Font{variant}{sizeVariant}Size`] or theme.FontMainBodySize
end

local function HighlightGradient(
    theme: Types.Theme,
    scope: Fusion.Scope,
    transparency: number
)
    return New(scope, "UIGradient") {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(
                0,
                Fusion.peek<<Color3>>(theme:GetFg(scope, "Primary"))
            ),
            ColorSequenceKeypoint.new(
                1,
                Fusion.peek<<Color3>>(theme:GetBg(scope, "Primary"))
            )
        }),
        Rotation = 90,
        Transparency = NumberSequence.new(transparency)
    } :: UIGradient
end

local function CalcColorModifier(
    scope: Fusion.Scope,
    isHover: Fusion.UsedAs<boolean>,
    isPress: Fusion.UsedAs<boolean>,
    hoverMode: ("Stroke" | "Default")?
): Fusion.Computed<Types.ThemeColorModifier?>
    return Fusion.Computed(scope, function(use, scope): Types.ThemeColorModifier?
        local usedIsHover, usedIsPress =
            use<<boolean>>(isHover), use<<boolean>>(isPress)

        return
            if usedIsPress then "Press"
            elseif usedIsHover then
                if hoverMode == "Stroke" then "HoverStroke" else "Hover"
            else nil
    end)
end

return {
    GetBg = GetBg,
    GetBgHighlight = GetBgHighlight,
    GetFg = GetFg,
    GetAccent = GetAccent,
    GetHeight = GetHeight,
    GetCornerRadius = GetCornerRadius,
    GetFont = GetFont,
    GetFontSize = GetFontSize,
    HighlightGradient = HighlightGradient,
    CalcColorModifier = CalcColorModifier
}
