--!strict

local ColorSpace =
    require("../../utils/colorSpace")
local TintHeaderColor =
    require("./headerColorTint")

local Epsilon = 1e-6
local MaxTintDistance = 0.02

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

local baseColor = Color3.fromRGB(48, 50, 58)
local firstTint = TintHeaderColor(baseColor, "Appearance")
local repeatedTint = TintHeaderColor(baseColor, "Appearance")
local secondTint = TintHeaderColor(baseColor, "Transform")
local similarHeaderTint = TintHeaderColor(baseColor, "Character")
local extendedHeaderTint =
    TintHeaderColor(baseColor, "Character Jump Settings")

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

local baseOklab = ColorSpace.Oklab.From(baseColor)
local tintOklab = ColorSpace.Oklab.From(firstTint)
local tintDistance = math.sqrt(
    (tintOklab.a - baseOklab.a) ^ 2
    + (tintOklab.b - baseOklab.b) ^ 2
)

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

local emptyHeaderTint = TintHeaderColor(baseColor, "")
local unicodeHeaderTint = TintHeaderColor(baseColor, "Données")
assert(emptyHeaderTint ~= unicodeHeaderTint, "header bytes should affect the tint")

print("headerColorTint verification passed")
