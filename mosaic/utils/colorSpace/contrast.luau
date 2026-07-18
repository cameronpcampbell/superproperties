--!strict

export type Result = {
	ratio: number,

	normalTextAA: boolean,
	normalTextAAA: boolean,
	largeTextAA: boolean,
	largeTextAAA: boolean,
	uiAA: boolean,
}

const NORMAL_TEXT_AA_RATIO = 4.5
const NORMAL_TEXT_AAA_RATIO = 7
const LARGE_TEXT_AA_RATIO = 3
const LARGE_TEXT_AAA_RATIO = 4.5
const UI_AA_RATIO = 3

local function RelativeLuminance(
	red: number,
	green: number,
	blue: number
): number
	return 0.2126 * red + 0.7152 * green + 0.0722 * blue
end

local function Check(
	firstLuminance: number,
	secondLuminance: number
): Result
	local lighter = math.max(firstLuminance, secondLuminance)
	local darker = math.min(firstLuminance, secondLuminance)
	local ratio = (lighter + 0.05) / (darker + 0.05)

	return {
		ratio = ratio,

		normalTextAA = ratio >= NORMAL_TEXT_AA_RATIO,
		normalTextAAA = ratio >= NORMAL_TEXT_AAA_RATIO,
		largeTextAA = ratio >= LARGE_TEXT_AA_RATIO,
		largeTextAAA = ratio >= LARGE_TEXT_AAA_RATIO,
		uiAA = ratio >= UI_AA_RATIO,
	}
end

return {
	RelativeLuminance = RelativeLuminance,
	Check = Check,
}
