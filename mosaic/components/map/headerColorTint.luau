--!strict

local Utils = script.Parent.Parent.Parent.utils
local ColorSpace = require(Utils.colorSpace)

local Uint32Mask = 0xFFFFFFFF
local Uint32Scale = 4_294_967_296
local HeaderColorTintChroma = 0.18
local HeaderColorTintStrength = 0.04
local Tau = 2 * math.pi

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

local function TintHeaderColor(
    headerBaseColor: Color3,
    header: string
): Color3
    local tintHue =
        HashHeader("hue\0" .. header) / Uint32Scale * Tau
    local headerBaseColorOklab =
        ColorSpace.Oklab.From(headerBaseColor)
    local headerTintColorOklab = ColorSpace.Oklch.new(
        headerBaseColorOklab.lightness,
        HeaderColorTintChroma,
        tintHue
    ):ToOklab()

    return headerBaseColorOklab
        :Lerp(headerTintColorOklab :: any, HeaderColorTintStrength)
        :ToColor3()
end

return TintHeaderColor
