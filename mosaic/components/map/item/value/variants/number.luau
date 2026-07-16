
--!strict

local CreateTextVariant = require(script.Parent.utils.createTextVariant)

local function FormatValue(value: number): string
    return tostring(math.round(value * 100) / 100)
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
