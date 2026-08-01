--!strict

local ColorSpace = require("../colorSpace")
local Constants = require("./constants")
local GetBestColor = require("./getBestColor")

local LightContrastCandidate =
    ColorSpace.Srgb.From(Constants.BASE_LIGHT_TEXT_COLOR)
local DarkContrastCandidate =
    ColorSpace.Srgb.From(Constants.BASE_DARK_TEXT_COLOR)

local function VerifyBestCandidate(surfaceColor: Color3)
    local surface = ColorSpace.Srgb.From(surfaceColor)
    local lightRatio =
        surface:CheckContrast(LightContrastCandidate).ratio
    local darkRatio =
        surface:CheckContrast(DarkContrastCandidate).ratio
    local selectedColor = GetBestColor(
        surfaceColor,
        Constants.BASE_LIGHT_TEXT_COLOR,
        Constants.BASE_DARK_TEXT_COLOR
    )

    if selectedColor == Constants.BASE_LIGHT_TEXT_COLOR then
        assert(
            lightRatio >= darkRatio,
            "light foreground should have the better contrast ratio"
        )
    else
        assert(
            selectedColor == Constants.BASE_DARK_TEXT_COLOR,
            "the selected color should be a base foreground color"
        )
        assert(
            darkRatio > lightRatio,
            "dark foreground should have the better contrast ratio"
        )
    end
end

assert(
    GetBestColor(
        Color3.new(0, 0, 0),
        Constants.BASE_LIGHT_TEXT_COLOR,
        Constants.BASE_DARK_TEXT_COLOR
    )
        == Constants.BASE_LIGHT_TEXT_COLOR,
    "dark surfaces should use the light foreground"
)
assert(
    GetBestColor(
        Color3.new(1, 1, 1),
        Constants.BASE_LIGHT_TEXT_COLOR,
        Constants.BASE_DARK_TEXT_COLOR
    )
        == Constants.BASE_DARK_TEXT_COLOR,
    "light surfaces should use the dark foreground"
)

for _, surfaceColor in {
    Color3.fromRGB(196, 40, 28),
    Color3.fromRGB(13, 105, 172),
    Color3.fromRGB(245, 205, 48),
    Color3.fromRGB(163, 162, 165),
} do
    VerifyBestCandidate(surfaceColor)
end

print("getBestColor verification passed")
