--!strict

local CreateTextVariant = require(script.Parent.utils.createTextVariant)
local ParseVector = require(script.parser)

type VectorValue = Vector3 | vector

local function FormatComponent(value: number): string
    return tostring(math.round(value * 100) / 100)
end

local function FormatValue(value: VectorValue): string
    local runtimeValue = value :: any
    local x = FormatComponent(runtimeValue.X)
    local y = FormatComponent(runtimeValue.Y)
    local z = FormatComponent(runtimeValue.Z)

    return `{x}, {y}, {z}`
end

local function ParseValue(text: string): (VectorValue?, string?)
    local components, parseError = ParseVector(text)
    if components == nil then
        return nil, parseError
    end

    return Vector3.new(components.X, components.Y, components.Z), nil
end

return CreateTextVariant<<VectorValue>>({
    InputName = "VectorValueInput",
    Format = FormatValue,
    Parse = ParseValue
})
