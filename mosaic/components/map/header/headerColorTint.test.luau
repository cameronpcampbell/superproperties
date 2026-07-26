--!strict

local ColorSpace =
    require("../../../utils/colorSpace")
local TintHeaderColor =
    require("./headerColorTint")

local Epsilon = 1e-6
local MaxTintDistance = 0.02
local MinimumExpectedHueSeparation = math.rad(89)
local Tau = 2 * math.pi
local BackgroundTarget: "Background" = "Background"
local ForegroundTarget: "Foreground" = "Foreground"
local LightContrastCandidate =
    ColorSpace.Srgb.From(Color3.fromHex("#F8FAFC"))
local DarkContrastCandidate =
    ColorSpace.Srgb.From(Color3.fromHex("#09090b"))

local function AssertNear(
    actual: number,
    expected: number,
    label: string,
    tolerance: number?
)
    local resolvedTolerance = tolerance or Epsilon

    assert(
        math.abs(actual - expected) <= resolvedTolerance,
        `{label}: expected {expected}, got {actual}`
    )
end

local function AssertColorEqual(
    actual: Color3,
    expected: Color3,
    label: string
)
    AssertNear(actual.R, expected.R, `{label} red`)
    AssertNear(actual.G, expected.G, `{label} green`)
    AssertNear(actual.B, expected.B, `{label} blue`)
end

local function GetTintDistance(baseColor: Color3, tintedColor: Color3): number
    local baseOklab = ColorSpace.Oklab.From(baseColor)
    local tintedOklab = ColorSpace.Oklab.From(tintedColor)

    return math.sqrt(
        (tintedOklab.a - baseOklab.a) ^ 2
        + (tintedOklab.b - baseOklab.b) ^ 2
    )
end

local function GetHue(color: Color3): number
    return ColorSpace.Oklch.From(color).hue
end

local function GetHueDistance(firstHue: number, secondHue: number): number
    local difference = math.abs(firstHue - secondHue) % Tau
    return math.min(difference, Tau - difference)
end

local baseColor = Color3.fromRGB(48, 50, 58)
local firstTint =
    TintHeaderColor(baseColor, "Appearance", BackgroundTarget)
local repeatedTint =
    TintHeaderColor(baseColor, "Appearance", BackgroundTarget)
local secondTint =
    TintHeaderColor(baseColor, "Transform", BackgroundTarget)
local similarHeaderTint =
    TintHeaderColor(baseColor, "Character", BackgroundTarget)
local extendedHeaderTint =
    TintHeaderColor(
        baseColor,
        "Character Jump Settings",
        BackgroundTarget
    )
local foregroundTint =
    TintHeaderColor(baseColor, "Appearance", ForegroundTarget)

AssertColorEqual(
    firstTint,
    repeatedTint,
    "the same header should have a stable tint"
)

assert(
    firstTint ~= secondTint,
    "different headers should produce different tints"
)
assert(
    similarHeaderTint ~= extendedHeaderTint,
    "similar headers should produce different tints"
)
assert(
    firstTint ~= foregroundTint,
    "background and foreground should use different chroma"
)

local baseOklab = ColorSpace.Oklab.From(baseColor)
local tintOklab = ColorSpace.Oklab.From(firstTint)
local tintDistance = GetTintDistance(baseColor, firstTint)
local foregroundTintDistance =
    GetTintDistance(baseColor, foregroundTint)

AssertNear(
    tintOklab.lightness,
    baseOklab.lightness,
    "tint should preserve perceptual lightness",
    1e-5
)
assert(
    tintDistance > 0 and tintDistance <= MaxTintDistance,
    `expected a subtle tint distance up to {MaxTintDistance}, got {tintDistance}`
)
assert(
    foregroundTintDistance > tintDistance,
    "foreground tint should use more chroma than the background tint"
)

local darkBaseColor = Color3.fromRGB(32, 32, 32)
local lightBaseColor = Color3.fromRGB(235, 235, 235)
local darkBaseSrgb = ColorSpace.Srgb.From(darkBaseColor)
local lightBaseSrgb = ColorSpace.Srgb.From(lightBaseColor)

assert(
    darkBaseSrgb:CheckContrast(LightContrastCandidate).ratio
        >= darkBaseSrgb:CheckContrast(DarkContrastCandidate).ratio,
    "the dark fixture should be classified as dark by contrast"
)
assert(
    lightBaseSrgb:CheckContrast(DarkContrastCandidate).ratio
        > lightBaseSrgb:CheckContrast(LightContrastCandidate).ratio,
    "the light fixture should be classified as light by contrast"
)

local darkBackgroundTint =
    TintHeaderColor(darkBaseColor, "Appearance", BackgroundTarget)
local lightBackgroundTint =
    TintHeaderColor(lightBaseColor, "Appearance", BackgroundTarget)
local darkTintDistance =
    GetTintDistance(darkBaseColor, darkBackgroundTint)
local lightTintDistance =
    GetTintDistance(lightBaseColor, lightBackgroundTint)

assert(
    lightTintDistance > darkTintDistance,
    "light colors should receive the stronger tint"
)

local lightForegroundTint =
    TintHeaderColor(lightBaseColor, "Appearance", ForegroundTarget)
local tintedContrast = ColorSpace.Srgb.From(darkBackgroundTint)
    :CheckContrast(ColorSpace.Srgb.From(lightForegroundTint))

assert(
    tintedContrast.normalTextAA,
    "representative tinted header colors should retain readable contrast"
)

local emptyHeaderTint =
    TintHeaderColor(baseColor, "", BackgroundTarget)
local unicodeHeaderTint =
    TintHeaderColor(baseColor, "Données", BackgroundTarget)
assert(emptyHeaderTint ~= unicodeHeaderTint, "header bytes should affect the tint")

local neutralBaseColor = Color3.fromRGB(128, 128, 128)
local canonicalPreviousTint =
    TintHeaderColor(neutralBaseColor, "Appearance", BackgroundTarget)
local explicitNilPreviousTint =
    TintHeaderColor(
        neutralBaseColor,
        "Appearance",
        BackgroundTarget,
        nil
    )
local adjacentTint =
    TintHeaderColor(
        neutralBaseColor,
        "Transform",
        BackgroundTarget,
        "Appearance"
    )
local repeatedAdjacentTint =
    TintHeaderColor(
        neutralBaseColor,
        "Transform",
        BackgroundTarget,
        "Appearance"
    )
local differentPreviousTint =
    TintHeaderColor(
        neutralBaseColor,
        "Transform",
        BackgroundTarget,
        "Data"
    )

AssertColorEqual(
    canonicalPreviousTint,
    explicitNilPreviousTint,
    "omitting the previous header should preserve the canonical tint"
)
AssertColorEqual(
    adjacentTint,
    repeatedAdjacentTint,
    "the same adjacent header pair should have a stable tint"
)
assert(
    adjacentTint ~= differentPreviousTint,
    "the previous header should influence the current tint"
)

local adjacentHueDistance = GetHueDistance(
    GetHue(canonicalPreviousTint),
    GetHue(adjacentTint)
)
assert(
    adjacentHueDistance >= MinimumExpectedHueSeparation,
    `expected adjacent hues to be separated, got {math.deg(adjacentHueDistance)} degrees`
)

local adjacentForegroundTint =
    TintHeaderColor(
        neutralBaseColor,
        "Transform",
        ForegroundTarget,
        "Appearance"
    )
assert(
    GetHueDistance(
        GetHue(adjacentTint),
        GetHue(adjacentForegroundTint)
    ) <= 1e-4,
    "background and foreground should use the same adjacent hue"
)

local repeatedHeaderTint =
    TintHeaderColor(
        neutralBaseColor,
        "Appearance",
        BackgroundTarget,
        "Appearance"
    )
assert(
    GetHueDistance(
        GetHue(canonicalPreviousTint),
        GetHue(repeatedHeaderTint)
    ) >= MinimumExpectedHueSeparation,
    "identical consecutive headers should still be separated"
)

print("headerColorTint verification passed")
