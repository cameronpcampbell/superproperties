
--!strict

local CreateTextVariant = require(script.Parent.utils.createTextVariant)
local NormalizeNumber = require(script.Parent.utils.normalizeNumber)

local function FormatValue(value: number): string
    return tostring(NormalizeNumber(value))
end

local function ParseValue(text: string): (number?, string?)
    local value = tonumber(text)
    if value == nil then
        return nil, "Enter a valid number."
    end

    return value, nil
end

return CreateTextVariant<<number>>({
    InputName = "NumberValueInput",
    Format = FormatValue,
    Parse = ParseValue
})
