--!strict

local Utils = script.Parent.Parent.Parent.Parent.utils
local ColorSpace = require(Utils.colorSpace)
local ThemeConstants = require(Utils.themeUtils.constants)

export type TintTarget = "Background" | "Foreground"

local Uint32Mask = 0xFFFFFFFF
local Uint32Scale = 4_294_967_296
local HeaderColorTintChroma: { [TintTarget]: number } = {
    Background = 0.22,
    Foreground = .804,
}
local DarkHeaderColorTintStrength = 0.04
local LightHeaderColorTintStrength = 0.06
local LightContrastCandidate =
    ColorSpace.Srgb.From(ThemeConstants.BASE_LIGHT_TEXT_COLOR)
local DarkContrastCandidate =
    ColorSpace.Srgb.From(ThemeConstants.BASE_DARK_TEXT_COLOR)
local Tau = 2 * math.pi
local MinimumAdjacentHueSeparation = math.rad(90)

local function AddUint32(left: number, right: number): number
    return bit32.band(left + right, Uint32Mask)
end

local function HashHeader(header: string): number
    local hash = 0

    for idx = 1, #header do
        hash = AddUint32(hash, string.byte(header, idx))
        hash = AddUint32(hash, bit32.lshift(hash, 10))
        hash = bit32.bxor(hash, bit32.rshift(hash, 6))
    end

    hash = AddUint32(hash, bit32.lshift(hash, 3))
    hash = bit32.bxor(hash, bit32.rshift(hash, 11))
    hash = AddUint32(hash, bit32.lshift(hash, 15))

    return hash
end

local function GetTintStrength(headerBaseColor: Color3): number
    local headerBaseColorSrgb = ColorSpace.Srgb.From(headerBaseColor)
    local lightContrast =
        headerBaseColorSrgb:CheckContrast(LightContrastCandidate)
    local darkContrast =
        headerBaseColorSrgb:CheckContrast(DarkContrastCandidate)
    local isDark = lightContrast.ratio >= darkContrast.ratio

    return if isDark then DarkHeaderColorTintStrength
        else LightHeaderColorTintStrength
end

local function GetHashedHue(header: string): number
    return HashHeader("hue\0" .. header) / Uint32Scale * Tau
end

local function GetTintHue(
    header: string,
    previousHeader: string?
): number
    if not previousHeader then
        return GetHashedHue(header)
    end

    local previousHue = GetHashedHue(previousHeader)
    local offsetUnit = HashHeader(
        "hue-offset\0" .. previousHeader .. "\0" .. header
    ) / Uint32Scale
    local availableArc =
        Tau - 2 * MinimumAdjacentHueSeparation
    local offset =
        MinimumAdjacentHueSeparation + offsetUnit * availableArc

    return (previousHue + offset) % Tau
end

local function TintHeaderColor(
    headerBaseColor: Color3,
    header: string,
    target: TintTarget,
    previousHeader: string?
): Color3
    local tintHue = GetTintHue(header, previousHeader)
    local headerBaseColorOklab =
        ColorSpace.Oklab.From(headerBaseColor)
    local headerTintColorOklab = ColorSpace.Oklch.new(
        headerBaseColorOklab.lightness,
        HeaderColorTintChroma[target],
        tintHue
    ):ToOklab()

    return headerBaseColorOklab
        :Lerp(
            headerTintColorOklab :: any,
            GetTintStrength(headerBaseColor)
        )
        :ToColor3()
end

return TintHeaderColor
