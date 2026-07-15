--!strict

local Packages = script.Parent.Parent.Parent.Parent
local Fusion = require(Packages.fusion)

local Types = require(script.Parent.types)
local DefaultThemeConfig = require(script.Parent.defaultThemeConfig)
local ThemeHelpers = require(script.Parent.themeHelpers)
local CreateTheme = require(script.Parent.createTheme)

local Peek, Value = Fusion.peek, Fusion.Value

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

    "FgPrimary",
    "FgSecondary",
    "FgTertiary",

    "AccentPrimary",
    "AccentSecondary",
    "AccentDestructive",

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

local ThemeForScopes: { [Fusion.Scope]: Types.Theme } = {}

local function CreateThemeForScope(
    scope: Fusion.Scope,
    config: Types.ThemeConfig
): Types.Theme
    local source = CreateTheme(config)

    table.insert(scope, function()
        ThemeForScopes[scope] = nil
    end)

    local theme = {
        GetBg = ThemeHelpers.GetBg,
        GetBgHighlight = ThemeHelpers.GetBgHighlight,
        GetFg = ThemeHelpers.GetFg,
        GetAccent = ThemeHelpers.GetAccent,
        GetHeight = ThemeHelpers.GetHeight,
        GetCornerRadius = ThemeHelpers.GetCornerRadius,
        GetFont = ThemeHelpers.GetFont,
        GetFontSize = ThemeHelpers.GetFontSize,
        HighlightGradient = ThemeHelpers.HighlightGradient,
    } :: any

    for _, key in THEME_TOKEN_KEYS do
        theme[key] = Value(scope, Peek((source :: any)[key]))
    end

    ThemeForScopes[scope] = theme

    return theme
end

local function SetThemeForScope(scope: Fusion.Scope, config: Types.ThemeConfig)
    local theme = ThemeForScopes[scope]

    if not theme then
        CreateThemeForScope(scope, config)
        return
    end

    local source = CreateTheme(config)

    for _, key in THEME_TOKEN_KEYS do
        local themeValue = (theme :: any)[key] :: Fusion.Value<any>
        themeValue:set(Peek((source :: any)[key]))
    end
end

local function GetThemeForScope(scope: Fusion.Scope): Types.Theme
    local theme = ThemeForScopes[scope]

    if not theme then
        theme = CreateThemeForScope(scope, DefaultThemeConfig)
    end

    return theme
end

return {
    SetThemeForScope = SetThemeForScope,
    GetThemeForScope = GetThemeForScope,
}
