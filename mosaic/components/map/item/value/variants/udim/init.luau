--!strict

local CreateTextVariant = require(script.Parent.utils.createTextVariant)
local NormalizeNumber = require(script.Parent.utils.normalizeNumber)
local ParseUDim = require(script.parser)

local function FormatComponent(value: number): string
    return tostring(NormalizeNumber(value))
end

local function FormatValue(value: UDim): string
    local scale = FormatComponent(value.Scale)
    local offset = FormatComponent(value.Offset)

    return `{scale}, {offset}`
end

local function ParseValue(text: string): (UDim?, string?)
    local components, parseError = ParseUDim(text)
    if components == nil then
        return nil, parseError
    end

    return UDim.new(components.Scale, components.Offset), nil
end

return CreateTextVariant<<UDim>>({
    InputName = "UDimValueInput",
    Format = FormatValue,
    Parse = ParseValue
})
