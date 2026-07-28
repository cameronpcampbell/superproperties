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

print("CFrame parser verification passed")
