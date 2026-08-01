--!strict

local Packages = script.Parent.Parent.Parent.Parent
local Fusion = require(Packages.fusion)

local Utils = script.Parent.Parent
local ColorSpace = require(Utils.colorSpace)

local Types = require(script.Parent.types)
local Constants = require(script.Parent.constants)

local Computed, New = Fusion.Computed, Fusion.New

local function LerpColor(from: Color3, to: Color3, alpha: number)
    return
        ColorSpace.Oklab.From(from)
            :Lerp(ColorSpace.Oklab.From(to), alpha)
            :ToColor3()
end

local function ComputeWithDefault(
    theme: Types.Theme,
    scope: Fusion.Scope,
    itemName: Fusion.UsedAs<string>,
    default: any
)
    return Computed(scope, function(use, scope)
        local usedItemName = use<<string>>(itemName)

        return use<<T>>(theme[usedItemName]) or default
    end)
end

local function ResolveColorModifier(
    theme: Types.Theme,
    use: Fusion.Use,
    color: Color3,
    modifier: Types.ThemeColorModifier?
): Color3
    return
        if modifier == "Hover" then
            LerpColor(color, use<<Color3>>(theme.BgPrimary), .1)

        elseif modifier == "HoverStroke" then
            LerpColor(color, use<<Color3>>(theme.FgPrimary), .1)

        elseif modifier == "Press" then
            LerpColor(color, use<<Color3>>(theme.BgPrimary), .2)

        else color
end

local function ApplyColorModifier(
    theme: Types.Theme,
    scope: Fusion.Scope,
    color: Fusion.UsedAs<Color3>,
    modifier: Fusion.UsedAs<Types.ThemeColorModifier?>
): Fusion.Computed<Color3>
    return Computed(scope, function(use, scope): Color3
        return ResolveColorModifier(
            theme,
            use,
            use<<Color3>>(color),
            use(modifier)
        )
    end)
end

local function ApplyNamedColorModifier(
    theme: Types.Theme,
    scope: Fusion.Scope,
    colorName: Fusion.UsedAs<string>,
    defaultColor: Fusion.UsedAs<Color3>,
    modifier: Fusion.UsedAs<Types.ThemeColorModifier?>
): Fusion.Computed<Color3>
    return Computed(scope, function(use, scope): Color3
        local usedColorName = use<<string>>(colorName)

        local usedColor =
            use<<Color3>>(theme[usedColorName] :: Fusion.UsedAs<Color3>) or
            use<<Color3>>(defaultColor)

        return ResolveColorModifier(theme, use, usedColor, use(modifier))
    end)
end

local function GetBg(
    theme: Types.Theme,
    scope: Fusion.Scope,
    variant: Fusion.UsedAs<Types.BgVariant>,
    modifier: Fusion.UsedAs<Types.ThemeColorModifier?>
): Fusion.UsedAs<Color3>
    local computeName = Computed(scope, function(use, scope)
        local usedVariant = use<<Types.BgVariant>>(variant)

        return `Bg{usedVariant}`
    end)

    return ApplyNamedColorModifier(
        theme, scope, computeName, theme.BgPrimary, modifier
    )
end

local function GetBgHighlight(
    theme: Types.Theme,
    scope: Fusion.Scope,
    variant: Fusion.UsedAs<Types.BgVariant>,
    modifier: Fusion.UsedAs<Types.ThemeColorModifier?>
): Fusion.UsedAs<Color3>
    local computeName = Computed(scope, function(use, scope)
        local usedVariant = use<<Types.BgVariant>>(variant)

        return `Bg{usedVariant}Highlight`
    end)

    return ApplyNamedColorModifier(
        theme, scope, computeName, theme.BgPrimaryHighlight, modifier
    )
end

local function GetFg(
    theme: Types.Theme,
    scope: Fusion.Scope,
    variant: Fusion.UsedAs<Types.FgVariant>,
    accentVariant: Fusion.UsedAs<Types.AccentVariant?>?,
    modifier: Fusion.UsedAs<Types.ThemeColorModifier?>
): Fusion.UsedAs<Color3>
    local computeName = Computed(scope, function(use, scope)
        local usedVariant = use<<Types.FgVariant>>(variant)
        local usedAccentVariant = use<<Types.AccentVariant?>>(accentVariant)

        return
            if usedAccentVariant then `Accent{usedAccentVariant}Fg{usedVariant}`
            else `Fg{usedVariant}`
    end)

    return ApplyNamedColorModifier(
        theme, scope, computeName, theme.FgPrimary, modifier
    )
end

local function GetAccent(
    theme: Types.Theme,
    scope: Fusion.Scope,
    variant: Fusion.UsedAs<Types.AccentVariant>,
    modifier: Fusion.UsedAs<Types.ThemeColorModifier?>
): Fusion.UsedAs<Color3>
    local computeName = Computed(scope, function(use, scope)
        local usedVariant = use<<Types.AccentVariant>>(variant)

        return `Accent{usedVariant}`
    end)

    return ApplyNamedColorModifier(
        theme, scope, computeName, theme.AccentPrimary, modifier
    )
end

local function GetAccentFg(
    theme: Types.Theme,
    scope: Fusion.Scope,
    variant: Fusion.UsedAs<Types.AccentVariant>,
    modifier: Fusion.UsedAs<Types.ThemeColorModifier?>
): Fusion.UsedAs<Color3>
    local computeName = Computed(scope, function(use, scope)
        local usedVariant = use<<Types.AccentVariant>>(variant)

        return `AccentFg{usedVariant}`
    end)

    return ApplyNamedColorModifier(
        theme, scope, computeName, theme.AccentPrimary, modifier
    )
end

local function GetHeight(
    theme: Types.Theme,
    scope: Fusion.Scope,
    variant: Fusion.UsedAs<Types.HeightVariant>
): Fusion.UsedAs<number>
    local computeName = Computed(scope, function(use, scope)
        local usedVariant = use<<Types.HeightVariant>>(variant)

        return `Height{usedVariant}`
    end)

    return ComputeWithDefault(
        theme, scope, computeName, theme.HeightLg
    )
end

local function GetCornerRadius(
    theme: Types.Theme,
    scope: Fusion.Scope,
    variant: Fusion.UsedAs<Types.CornerRadiusVariant>
): Fusion.UsedAs<number>
    local computeName = Computed(scope, function(use, scope)
        local usedVariant = use<<Types.CornerRadiusVariant>>(variant)

        return `CornerRadius{usedVariant}`
    end)

    return ComputeWithDefault(
        theme, scope, computeName, theme.CornerRadiusMd
    )
end

local function GetFont(
    theme: Types.Theme,
    scope: Fusion.Scope,
    variant: Fusion.UsedAs<Types.FontVariant>,
    weight: Fusion.UsedAs<Enum.FontWeight>?,
    style: Fusion.UsedAs<Enum.FontStyle>?
): Fusion.UsedAs<Font>
    return Computed(scope, function(use, scope): Font
        local usedVariant = use<<Types.FontVariant>>(variant)

        local font =
            use<<Font>>(theme[usedVariant] :: Fusion.UsedAs<Font>) or
            use<<Font>>(theme.FontMain)

        font.Weight = use<<FontWeight>>(weight)
            or Enum.FontWeight.Medium

        font.Style = use<<FontStyle>>(style)
            or Enum.FontStyle.Normal

        return font
    end)
end

local function GetFontSize(
    theme: Types.Theme,
    scope: Fusion.Scope,
    variant: Fusion.UsedAs<Types.FontVariant>,
    sizeVariant: Fusion.UsedAs<Types.FontSizeVariant>
): Fusion.UsedAs<number>
    local computeName = Computed(scope, function(use, scope)
        local usedVariant = use<<Types.FontVariant>>(variant)
        local usedSizeVariant = use<<Types.FontSizeVariant>>(sizeVariant)

        return `Font{usedVariant}{usedSizeVariant}Size`
    end)

    return ComputeWithDefault(
        theme, scope, computeName, theme.FontMainBodySize
    )
end

local function HighlightGradient(
    _theme: Types.Theme,
    scope: Fusion.Scope,
    transparency: Fusion.UsedAs<number>
)
    return New(scope, "UIGradient") {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(
                0,
                Constants.BASE_LIGHT_TEXT_COLOR
            ),
            ColorSequenceKeypoint.new(
                1,
                Constants.BASE_DARK_TEXT_COLOR
            ),
        }),
        Rotation = 90,
        Transparency = Computed(scope, function(use, scope)
            return NumberSequence.new(use(transparency))
        end),
    } :: UIGradient
end

local function CalcColorModifier(
    scope: Fusion.Scope,
    isHover: Fusion.UsedAs<boolean>,
    isPress: Fusion.UsedAs<boolean>,
    hoverMode: ("Stroke" | "Default")?
): Fusion.UsedAs<Types.ThemeColorModifier?>
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
    GetAccentFg = GetAccentFg,
    GetHeight = GetHeight,
    GetCornerRadius = GetCornerRadius,
    GetFont = GetFont,
    GetFontSize = GetFontSize,
    HighlightGradient = HighlightGradient,
    ApplyColorModifier = ApplyColorModifier,
    CalcColorModifier = CalcColorModifier
}
