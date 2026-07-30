--!strict

local ParseCFrame = require("./parser")

local flat, parseError =
    ParseCFrame("1 + 2, 8 / 2, 2 ^ 3")
assert(flat ~= nil, `expected flat CFrame components, got {parseError}`)
assert(
    flat.Position.X == 3
    and flat.Position.Y == 4
    and flat.Position.Z == 8
    and flat.Orientation == nil,
    "unexpected flat CFrame components"
)

local braced
braced, parseError =
    ParseCFrame("{1 + 2, 8 / 2, 2 ^ 3}, {90 / 2, 10 % 3, -2 ^ 2}")
assert(braced ~= nil, `expected braced CFrame components, got {parseError}`)
assert(braced.Orientation ~= nil, "expected orientation components")
assert(
    braced.Position.X == 3
    and braced.Position.Y == 4
    and braced.Position.Z == 8
    and braced.Orientation.X == 45
    and braced.Orientation.Y == 1
    and braced.Orientation.Z == -4,
    "unexpected braced CFrame components"
)

local permissiveFlat
permissiveFlat, parseError = ParseCFrame("1,,, 2,,, 3,,,")
assert(
    permissiveFlat ~= nil,
    `expected permissive flat CFrame components, got {parseError}`
)
assert(
    permissiveFlat.Position.X == 1
    and permissiveFlat.Position.Y == 2
    and permissiveFlat.Position.Z == 3
    and permissiveFlat.Orientation == nil,
    "unexpected permissive flat CFrame components"
)

local permissiveBraced
permissiveBraced, parseError =
    ParseCFrame("{1,,, 2,,, 3,,,},,, {4,,, 5,,, 6,,,},,,")
assert(
    permissiveBraced ~= nil,
    `expected permissive braced CFrame components, got {parseError}`
)
assert(
    permissiveBraced.Orientation ~= nil,
    "expected permissive orientation components"
)
assert(
    permissiveBraced.Position.X == 1
    and permissiveBraced.Position.Y == 2
    and permissiveBraced.Position.Z == 3
    and permissiveBraced.Orientation.X == 4
    and permissiveBraced.Orientation.Y == 5
    and permissiveBraced.Orientation.Z == 6,
    "unexpected permissive braced CFrame components"
)

local trailingPosition
trailingPosition, parseError = ParseCFrame("{1, 2, 3},")
assert(
    trailingPosition ~= nil,
    `expected trailing-comma position CFrame, got {parseError}`
)
assert(
    trailingPosition.Orientation == nil,
    "a trailing comma should not require an orientation"
)

print("CFrame parser verification passed")
