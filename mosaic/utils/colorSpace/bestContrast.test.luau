--!strict

local ColorSpace = require("../colorSpace")

local Black = Color3.new(0, 0, 0)
local Gray = Color3.new(0.5, 0.5, 0.5)
local White = Color3.new(1, 1, 1)

local blackSrgb = ColorSpace.Srgb.From(Black)
local whiteSrgb = ColorSpace.Srgb.From(White)
local secondWhiteSrgb = ColorSpace.Srgb.From(White)
local blackLinearRgb = ColorSpace.LinearRgb.From(Black)
local grayXyz = ColorSpace.Xyz.From(Gray)
local whiteOklab = ColorSpace.Oklab.From(White)
local whiteOklch = ColorSpace.Oklch.From(White)

assert(
	blackSrgb:BestContrast(blackLinearRgb, whiteOklab, grayXyz)
		== whiteOklab,
	"the best color can be the middle candidate"
)
assert(
	blackSrgb:BestContrast(blackLinearRgb, grayXyz, whiteOklch)
		== whiteOklch,
	"the best color can be the final candidate"
)
assert(
	blackSrgb:BestContrast(whiteSrgb, secondWhiteSrgb) == whiteSrgb,
	"equal contrast should preserve candidate order"
)
assert(
	whiteSrgb:BestContrast(grayXyz, blackLinearRgb) == blackLinearRgb,
	"candidates should be tested against the receiver"
)

assert(
	ColorSpace.LinearRgb.From(Black):BestContrast(
		blackSrgb,
		whiteOklab
	) == whiteOklab,
	"LinearRgb should expose BestContrast"
)
assert(
	ColorSpace.Xyz.From(Black):BestContrast(blackSrgb, whiteOklab)
		== whiteOklab,
	"Xyz should expose BestContrast"
)
assert(
	ColorSpace.Oklab.From(Black):BestContrast(blackSrgb, whiteOklab)
		== whiteOklab,
	"Oklab should expose BestContrast"
)
assert(
	ColorSpace.Oklch.From(Black):BestContrast(blackSrgb, whiteOklab)
		== whiteOklab,
	"Oklch should expose BestContrast"
)

print("bestContrast verification passed")
