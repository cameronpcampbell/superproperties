--!strict

local ParseUDim2 = require("./parser")

local flat, parseError =
    ParseUDim2("1 / 2, 8 / 2, 3 % 2, 2 ^ 3")
assert(flat ~= nil, `expected flat UDim2 components, got {parseError}`)
assert(
    flat.X.Scale == 0.5
    and flat.X.Offset == 4
    and flat.Y.Scale == 1
    and flat.Y.Offset == 8,
    "unexpected flat UDim2 components"
)

local braced
braced, parseError =
    ParseUDim2("{1 / 2, 2 ^ 2}, {(3 - 1) / 4, 2 ^ 3}")
assert(braced ~= nil, `expected braced UDim2 components, got {parseError}`)
assert(
    braced.X.Scale == 0.5
    and braced.X.Offset == 4
    and braced.Y.Scale == 0.5
    and braced.Y.Offset == 8,
    "unexpected braced UDim2 components"
)

local permissiveFlat
permissiveFlat, parseError =
    ParseUDim2("0.5,,, 4,,, 1,,, 8,,,")
assert(
    permissiveFlat ~= nil,
    `expected permissive flat UDim2 components, got {parseError}`
)
assert(
    permissiveFlat.X.Scale == 0.5
    and permissiveFlat.X.Offset == 4
    and permissiveFlat.Y.Scale == 1
    and permissiveFlat.Y.Offset == 8,
    "unexpected permissive flat UDim2 components"
)

local permissiveBraced
permissiveBraced, parseError =
    ParseUDim2("{0.5,,, 4,,,},,, {1,,, 8,,,},,,")
assert(
    permissiveBraced ~= nil,
    `expected permissive braced UDim2 components, got {parseError}`
)
assert(
    permissiveBraced.X.Scale == 0.5
    and permissiveBraced.X.Offset == 4
    and permissiveBraced.Y.Scale == 1
    and permissiveBraced.Y.Offset == 8,
    "unexpected permissive braced UDim2 components"
)

print("UDim2 parser verification passed")
