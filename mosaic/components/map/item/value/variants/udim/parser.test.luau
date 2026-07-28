--!strict

local ParseUDim = require("./parser")

local components, parseError = ParseUDim("1 / 2, 2 ^ 3")
assert(components ~= nil, `expected UDim components, got {parseError}`)
assert(
    components.Scale == 0.5 and components.Offset == 8,
    `unexpected UDim components: {components.Scale}, {components.Offset}`
)

local scale
scale, parseError = ParseUDim("(3 - 1) / 4")
assert(scale ~= nil, `expected a scale expression, got {parseError}`)
assert(
    scale.Scale == 0.5 and scale.Offset == 0,
    `unexpected scale expression result: {scale.Scale}, {scale.Offset}`
)

local offset
offset, parseError = ParseUDim("2 * 3")
assert(offset ~= nil, `expected an offset expression, got {parseError}`)
assert(
    offset.Scale == 0 and offset.Offset == 6,
    `unexpected offset expression result: {offset.Scale}, {offset.Offset}`
)

print("UDim parser verification passed")
