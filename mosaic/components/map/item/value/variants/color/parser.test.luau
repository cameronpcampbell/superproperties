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
AssertColor("#123456", Color3.fromHex("123456"), "hexadecimal")

local outOfRangeColor, outOfRangeError = ParseColor("256, 0, 0")
assert(
    outOfRangeColor == nil and outOfRangeError ~= nil,
    "values above 255 should remain invalid"
)

print("color parser verification passed")
