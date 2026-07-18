--!strict

local CreateTextVariant = require(script.Parent.utils.createTextVariant)
local NormalizeNumber = require(script.Parent.utils.normalizeNumber)
local ParseVector2 = require(script.parser)

local function FormatComponent(value: number): string
    return tostring(NormalizeNumber(value))
end

local function FormatValue(value: Vector2): string
    local x = FormatComponent(value.X)
    local y = FormatComponent(value.Y)

    return `{x}, {y}`
end

local function ParseValue(text: string): (Vector2?, string?)
    local components, parseError = ParseVector2(text)
    if components == nil then
        return nil, parseError
    end

    return Vector2.new(components.X, components.Y), nil
end

return CreateTextVariant<<Vector2>>({
    InputName = "Vector2ValueInput",
    Format = FormatValue,
    Parse = ParseValue
})
