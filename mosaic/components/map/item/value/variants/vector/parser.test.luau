--!strict

local ParseVector = require("./parser")

local function AssertVector(
    text: string,
    expectedX: number,
    expectedY: number,
    expectedZ: number,
    label: string
)
    local actual, parseError = ParseVector(text)
    assert(
        actual ~= nil,
        `{label}: expected vector components, got {parseError}`
    )
    assert(
        actual.X == expectedX
        and actual.Y == expectedY
        and actual.Z == expectedZ,
        `{label}: got {actual.X}, {actual.Y}, {actual.Z}`
    )
end

AssertVector(
    "1 + 2, (8 / 2), 2 ^ 3",
    3,
    4,
    8,
    "expression components"
)
AssertVector("2 * 3", 6, 6, 6, "shared expression")

local invalid, parseError = ParseVector("1 2, 3, 4")
assert(
    invalid == nil and parseError ~= nil,
    "whitespace-separated numbers should remain invalid"
)

print("vector parser verification passed")
