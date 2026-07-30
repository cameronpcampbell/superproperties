--!strict

local ParseColor = require("./parser")

local Epsilon = 1e-6

local function AssertColor(
    text: string,
    expected: Color3,
    label: string
)
    local actual, parseError = ParseColor(text)
    assert(actual ~= nil, `{label}: expected a color, got {parseError}`)

    assert(
        math.abs(actual.R - expected.R) <= Epsilon and
        math.abs(actual.G - expected.G) <= Epsilon and
        math.abs(actual.B - expected.B) <= Epsilon,
        `{label}: expected {expected}, got {actual}`
    )
end

AssertColor(
    "0.5, 0.25, 1",
    Color3.fromRGB(127.5, 63.75, 255),
    "normalized decimals"
)
AssertColor(
    "0, 1, 0",
    Color3.fromRGB(0, 255, 0),
    "normalized integers"
)
AssertColor(
    "0.5, 128, 255",
    Color3.fromRGB(0.5, 128, 255),
    "mixed ranges"
)
AssertColor(
    "-10, 20, -30",
    Color3.fromRGB(0, 20, 0),
    "negative components"
)
AssertColor(
    "255 / 2, 2 ^ 7, 10 % 3",
    Color3.fromRGB(127.5, 128, 1),
    "math expression components"
)
AssertColor(
    "255,,, 0,,, 128,,,",
    Color3.fromRGB(255, 0, 128),
    "chained and trailing commas"
)
AssertColor("#123456", Color3.fromHex("123456"), "hexadecimal")

local outOfRangeColor, outOfRangeError = ParseColor("256, 0, 0")
assert(
    outOfRangeColor == nil and outOfRangeError ~= nil,
    "values above 255 should remain invalid"
)

local incompleteColor, incompleteError = ParseColor("255,,, 0,,,")
assert(
    incompleteColor == nil and incompleteError ~= nil,
    "incomplete RGB lists should remain invalid"
)

local leadingCommaColor, leadingCommaError = ParseColor(",,,255, 0, 0")
assert(
    leadingCommaColor == nil and leadingCommaError ~= nil,
    "leading RGB commas should remain invalid"
)

local trailingHexColor, trailingHexError = ParseColor("#123456,")
assert(
    trailingHexColor == nil and trailingHexError ~= nil,
    "hexadecimal colors should not accept trailing commas"
)

print("color parser verification passed")
