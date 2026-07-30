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

local permissive
permissive, parseError = ParseVector2("3,,, 4,,,")
assert(
    permissive ~= nil,
    `expected permissive Vector2 components, got {parseError}`
)
assert(
    permissive.X == 3 and permissive.Y == 4,
    `unexpected permissive Vector2 components: {permissive.X}, {permissive.Y}`
)

local trailingShared
trailingShared, parseError = ParseVector2("5,")
assert(
    trailingShared ~= nil,
    `expected trailing-comma shared Vector2 components, got {parseError}`
)
assert(
    trailingShared.X == 5 and trailingShared.Y == 5,
    "unexpected trailing-comma shared Vector2 components"
)

print("Vector2 parser verification passed")
