--!strict

local Packages = script.Parent.Parent.Parent.Parent
local Fusion = require(Packages.fusion)

local FusionUtils = require(script.Parent.Parent.fusionUtils)

local Types = require(script.Parent.types)
local DefaultThemeConfig = require(script.Parent.defaultThemeConfig)
local ThemeHelpers = require(script.Parent.themeHelpers)
local CreateTheme = require(script.Parent.createTheme)

local Peek, Value = Fusion.peek, Fusion.Value
local ScopedData = FusionUtils.ScopedData

local THEME_TOKEN_KEYS: { [number]: keyof<Types.ThemeSource> } = {
    "BgPrimary",
    "BgSecondary",
    "BgTertiary",
    "BgQuaternary",
    "BgQuinary",

    "BgPrimaryHighlight",
    "BgSecondaryHighlight",
    "BgTertiaryHighlight",
    "BgQuaternaryHighlight",
    "BgQuinaryHighlight",

    "FgPrimary",
    "FgSecondary",
    "FgTertiary",

    "AccentPrimary",
    "AccentSecondary",
    "AccentDestructive",

    "AccentFgPrimary",
    "AccentFgSecondary",
    "AccentFgTertiary",

    "HeightSm",
    "HeightMd",
    "HeightLg",

    "CornerRadiusSm",
    "CornerRadiusMd",
    "CornerRadiusLg",

    "FontMain",
    "FontMono",

    "FontMainTitleSize",
    "FontMainBodySize",
    "FontMainCaptionSize",

    "FontMonoTitleSize",
    "FontMonoBodySize",
    "FontMonoCaptionSize",
}

local function CreateThemeState(
    scope: Fusion.Scope,
    config: Types.ThemeConfig
): Types.Theme
    local source = CreateTheme(config)

    local theme = {
        GetBg = ThemeHelpers.GetBg,
        GetBgHighlight = ThemeHelpers.GetBgHighlight,
        GetFg = ThemeHelpers.GetFg,
        GetAccent = ThemeHelpers.GetAccent,
        GetAccentFg = ThemeHelpers.GetAccentFg,
        GetHeight = ThemeHelpers.GetHeight,
        GetCornerRadius = ThemeHelpers.GetCornerRadius,
        GetFont = ThemeHelpers.GetFont,
        GetFontSize = ThemeHelpers.GetFontSize,
        HighlightGradient = ThemeHelpers.HighlightGradient,
    } :: any

    for _, key in THEME_TOKEN_KEYS do
        theme[key] = Value(scope, Peek((source :: any)[key]))
    end

    return theme
end

local function UpdateTheme(theme: Types.Theme, config: Types.ThemeConfig)
    local source = CreateTheme(config)

    for _, key in THEME_TOKEN_KEYS do
        local themeValue = (theme :: any)[key] :: Fusion.Value<any>
        themeValue:set(Peek((source :: any)[key]))
    end
end

local function SetThemeForScope(scope: Fusion.Scope, config: Types.ThemeConfig)
    local created = false
    local theme: Types.Theme = ScopedData(scope, "Theme", {
        Mode = "Scoped",
        Create = function(_parent: Types.Theme?)
            created = true
            return CreateThemeState(scope, config)
        end,
    })

    if not created then UpdateTheme(theme, config) end
end

local function GetThemeForScope(scope: Fusion.Scope): Types.Theme
    return ScopedData(scope, "Theme", {
        Create = function(_parent: Types.Theme?)
            return CreateThemeState(scope, DefaultThemeConfig())
        end,
    })
end

return {
    SetThemeForScope = SetThemeForScope,
    GetThemeForScope = GetThemeForScope,
}
