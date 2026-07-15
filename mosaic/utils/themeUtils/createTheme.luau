--!strict

local Utils = script.Parent.Parent

local ColorSpace = require(Utils.colorSpace)
local IsDark = ColorSpace.Utils.IsDark

local Types = require(script.Parent.types)

local function GenPalette(
	color: Color3,
	amount: number,
	lightnessStrength: number?,
	chromaStrength: number?
): { Color3 }
    local lightness, chroma, hue = ColorSpace.Oklch.From(color):Components()

    local lightnessIntensity: number = lightnessStrength or 1
	local chromaIntensity: number = chromaStrength or 0
	local lightnessRange: number = if lightnessIntensity >= 0 then 1 - lightness else lightness

	local palette = table.create(amount) :: { Color3 }
	palette[1] = color

	for idx = 2, amount do
		local progress: number = (idx - 1) / (amount - 1)
		local newLightness: number = lightness + lightnessRange * progress * lightnessIntensity
		local newChroma: number = chroma + progress * chromaIntensity
		palette[idx] = ColorSpace.Oklch.new(newLightness, newChroma, hue):ToColor3()
	end

	return palette
end

local function GenLerpedPalette(colors: { Color3 }, alpha: number): { Color3 }
	local palette = table.create(#colors - 1) :: { Color3 }

	local lastColor = ColorSpace.Oklab.From(colors[1])

	for idx = 1, #colors - 1 do
	    local thisColor = ColorSpace.Oklab.From(colors[idx + 1])

		palette[idx] = ColorSpace.Oklab.Lerp(lastColor, thisColor, alpha):ToColor3()

		lastColor = thisColor
	end

	return palette
end

local function ApplyChroma(source: Color3, target: Color3, strength: number?): Color3
	local _, sourceChroma, _ = ColorSpace.Oklch.From(source):Components()
	local targetLightness, targetChroma, targetHue =
	    ColorSpace.Oklch.From(target):Components()

	local intensity: number = strength or 1
	local newChroma: number = targetChroma + (sourceChroma - targetChroma) * intensity

	return ColorSpace.Oklch.new(targetLightness, newChroma, targetHue):ToColor3()
end

const BASE_LIGHT_TEXT_COLOR = Color3.fromHex("#F8FAFC")
const BASE_DARK_TEXT_COLOR = Color3.fromHex("#09090b")

const CORNER_RADIUS_SM = 3
const CORNER_RADIUS_MD = 6
const CORNER_RADIUS_LG = 9

local function CreateTheme(config: Types.ThemeConfig): Types.ThemeSource
    local bgBaseColor = config.BgBaseColor

    local bgColors = GenPalette(bgBaseColor, 5, .225, .017)
    local bgHighlightColors = GenLerpedPalette(bgColors, .5)

    local baseBgContrastColor, lightnessDirection
    if IsDark(bgBaseColor) then
        baseBgContrastColor, lightnessDirection = BASE_LIGHT_TEXT_COLOR, -1
    else
        baseBgContrastColor, lightnessDirection = BASE_DARK_TEXT_COLOR, 1
    end

    local baseFgColor = ApplyChroma(bgBaseColor, baseBgContrastColor, 1)
    local fgColors = GenPalette(baseFgColor, 3, .32 * lightnessDirection, .017)

    return {
        BgPrimary = bgColors[1],
        BgSecondary = bgColors[2],
        BgTertiary = bgColors[3],
        BgQuaternary = bgColors[4],
        BgQuinary = bgColors[5],

        BgPrimaryHighlight = bgHighlightColors[1],
        BgSecondaryHighlight = bgHighlightColors[2],
        BgTertiaryHighlight = bgHighlightColors[3],
        BgQuaternaryHighlight = bgHighlightColors[4],

        FgPrimary = fgColors[1],
        FgSecondary = fgColors[2],
        FgTertiary = fgColors[3],

        AccentPrimary = config.AccentPrimary,
        AccentSecondary = config.AccentSecondary,
        AccentDestructive = config.AccentDestructive,

        HeightSm = config.HeightSm,
        HeightMd = config.HeightMd,
        HeightLg = config.HeightLg,

        CornerRadiusSm = CORNER_RADIUS_SM,
        CornerRadiusMd = CORNER_RADIUS_MD,
        CornerRadiusLg = CORNER_RADIUS_LG,

        FontMain = config.FontMain,
        FontMono = config.FontMono,

        FontMainTitleSize = config.FontMainTitleSize,
        FontMainBodySize = config.FontMainBodySize,
        FontMainCaptionSize = config.FontMainCaptionSize,

        FontMonoTitleSize = config.FontMonoTitleSize,
        FontMonoBodySize = config.FontMonoBodySize,
        FontMonoCaptionSize = config.FontMonoCaptionSize
    }
end

return CreateTheme
