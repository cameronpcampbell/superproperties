--!strict

local CreateTextVariant = require(script.Parent.utils.createTextVariant)
local NormalizeNumber = require(script.Parent.utils.normalizeNumber)
local ParseUDim2 = require(script.parser)

local function FormatComponent(value: number): string
    return tostring(NormalizeNumber(value))
end

local function FormatValue(value: UDim2): string
    return string.format(
        "{%s, %s},{%s, %s}",
        FormatComponent(value.X.Scale),
        FormatComponent(value.X.Offset),
        FormatComponent(value.Y.Scale),
        FormatComponent(value.Y.Offset)
    )
end

local function ParseValue(text: string): (UDim2?, string?)
    local components, parseError = ParseUDim2(text)
    if components == nil then
        return nil, parseError
    end

    return UDim2.new(
        components.X.Scale,
        components.X.Offset,
        components.Y.Scale,
        components.Y.Offset
    ), nil
end

return CreateTextVariant<<UDim2>>({
    InputName = "UDim2ValueInput",
    Format = FormatValue,
    Parse = ParseValue
})
