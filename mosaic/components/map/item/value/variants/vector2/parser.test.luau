--!strict

local ParseVector2 = require("./parser")

local components, parseError =
    ParseVector2("(2 + 3) * 4, 2 ^ -2")
assert(components ~= nil, `expected Vector2 components, got {parseError}`)
assert(
    components.X == 20 and components.Y == 0.25,
    `unexpected Vector2 components: {components.X}, {components.Y}`
)

local shared
shared, parseError = ParseVector2("10 % 4")
assert(shared ~= nil, `expected shared Vector2 components, got {parseError}`)
assert(
    shared.X == 2 and shared.Y == 2,
    `unexpected shared Vector2 components: {shared.X}, {shared.Y}`
)

print("Vector2 parser verification passed")
