--!strict

local Utils = script.Parent.Parent

local ColorSpace = require(Utils.colorSpace)

local Types = require(script.Parent.types)

local function GenPalette(
	color: Color3,
	amount: number,
	lightnessStrength: number?,
	chromaStrength: number?,
	chromaHue: number?
): { Color3 }
    local lightness, chroma, hue = ColorSpace.Oklch.From(color):Components()

    local lightnessIntensity: number = lightnessStrength or 1
	local chromaIntensity: number = chromaStrength or 0
	local lightnessRange: number = if lightnessIntensity >= 0 then 1 - lightness else lightness

	local palette = table.create(amount) :: { Color3 }
	palette[1] = color

	for idx = 2, amount do
		local progress: number = (idx - 1) / (5 - 1)
		local newLightness: number = lightness + lightnessRange * progress * lightnessIntensity

		if chromaHue then
			local chromaOffset: number = progress * chromaIntensity
			local baseA: number = chroma * math.cos(hue)
			local baseB: number = chroma * math.sin(hue)

			palette[idx] = ColorSpace.Oklab.new(
				newLightness,
				baseA + chromaOffset * math.cos(chromaHue),
				baseB + chromaOffset * math.sin(chromaHue)
			):ToColor3()
		else
			local newChroma: number = chroma + progress * chromaIntensity
			palette[idx] = ColorSpace.Oklch.new(newLightness, newChroma, hue):ToColor3()
		end
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

const BASE_LIGHT_TEXT_COLOR = Color3.fromHex("#F8FAFC")
const BASE_DARK_TEXT_COLOR = Color3.fromHex("#09090b")
const BASE_BG_TINT_COLOR = Color3.fromRGB(25, 26, 31)

local _, _, BASE_BG_TINT_HUE =
	ColorSpace.Oklch.From(BASE_BG_TINT_COLOR):Components()

local function GenFgPalette(surfaceColor: Color3): { Color3 }
    local surface = ColorSpace.Srgb.From(surfaceColor)
    local lightContrast = surface:CheckContrast(
        ColorSpace.Srgb.From(BASE_LIGHT_TEXT_COLOR)
    )
    local darkContrast = surface:CheckContrast(
        ColorSpace.Srgb.From(BASE_DARK_TEXT_COLOR)
    )

    local useLightCandidate = lightContrast.ratio >= darkContrast.ratio
    local baseFgColor =
        if useLightCandidate then BASE_LIGHT_TEXT_COLOR
        else BASE_DARK_TEXT_COLOR
    local lightnessDirection = if useLightCandidate then -1 else 1

    return GenPalette(
        baseFgColor,
        3,
        .32 * lightnessDirection,
        .017
    )
end

const CORNER_RADIUS_SM = 3
const CORNER_RADIUS_MD = 6
const CORNER_RADIUS_LG = 9

local function CreateTheme(config: Types.ThemeConfig): Types.ThemeSource
    local bgBaseColor = config.BgBaseColor
    local isDarkTheme = ColorSpace.Srgb.From(bgBaseColor):IsDark()

    local bgLightnessDirection = if isDarkTheme then 1 else -1

    local bgColors = GenPalette(
        bgBaseColor,
        6,
        .225 * bgLightnessDirection,
        .017,
        BASE_BG_TINT_HUE
    )
    local bgHighlightColors = GenLerpedPalette(bgColors, .5)

    local fgColors = GenFgPalette(bgBaseColor)
    local accentFgColors = GenFgPalette(config.AccentPrimary)

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
        BgQuinaryHighlight = bgHighlightColors[5],

        FgPrimary = fgColors[1],
        FgSecondary = fgColors[2],
        FgTertiary = fgColors[3],

        AccentPrimary = config.AccentPrimary,
        AccentSecondary = config.AccentSecondary,
        AccentDestructive = config.AccentDestructive,

        AccentFgPrimary = accentFgColors[1],
        AccentFgSecondary = accentFgColors[2],
        AccentFgTertiary = accentFgColors[3],

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
