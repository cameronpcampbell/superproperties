--!strict

local Packages = script.Parent.Parent.Parent.Parent
local Fusion = require(Packages.fusion)

local FusionUtils = require(script.Parent.Parent.fusionUtils)

local Types = require(script.Parent.types)
local DefaultThemeConfig = require(script.Parent.defaultThemeConfig)
local ThemeHelpers = require(script.Parent.themeHelpers)
local CreateTheme = require(script.Parent.createTheme)

local Peek, Value = Fusion.peek, Fusion.Value
local Oktween, ScopedData = FusionUtils.Oktween, FusionUtils.ScopedData

local THEME_COLOR_TWEEN_INFO = TweenInfo.new(
    .55,
    Enum.EasingStyle.Exponential,
    Enum.EasingDirection.InOut
)

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

type ThemeTargets = {
    [keyof<Types.ThemeSource>]: Fusion.Value<any>,
}

type ManagedTheme = {
    Public: Types.Theme,
    Targets: ThemeTargets,
}

local function CreateManagedTheme(
    scope: Fusion.Scope,
    config: Types.ThemeConfig
): ManagedTheme
    local source = CreateTheme(config)
    local targets: ThemeTargets = {}

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
        local sourceValue = Peek((source :: any)[key])
        local target = Value(scope, sourceValue)

        targets[key] = target
        theme[key] =
            if typeof(sourceValue) == "Color3" then
                Oktween(scope, target, THEME_COLOR_TWEEN_INFO)
            else target
    end

    return {
        Public = theme,
        Targets = targets,
    }
end

local function UpdateTheme(
    managedTheme: ManagedTheme,
    config: Types.ThemeConfig
)
    local source = CreateTheme(config)

    for _, key in THEME_TOKEN_KEYS do
        managedTheme.Targets[key]:set(Peek((source :: any)[key]))
    end
end

local function SetThemeForScope(scope: Fusion.Scope, config: Types.ThemeConfig)
    local created = false
    local managedTheme = ScopedData<<ManagedTheme>>(scope, "Theme", {
        Mode = "Scoped",
        Create = function(_parent: ManagedTheme?)
            created = true
            return CreateManagedTheme(scope, config)
        end,
    })

    if not created then UpdateTheme(managedTheme, config) end
end

local function GetThemeForScope(scope: Fusion.Scope): Types.Theme
    local managedTheme = ScopedData<<ManagedTheme>>(scope, "Theme", {
        Create = function(_parent: ManagedTheme?)
            return CreateManagedTheme(scope, DefaultThemeConfig())
        end,
    })

    return managedTheme.Public
end

return {
    SetThemeForScope = SetThemeForScope,
    GetThemeForScope = GetThemeForScope,
}
