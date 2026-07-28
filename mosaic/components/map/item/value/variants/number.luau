
--!strict

local CreateTextVariant = require(script.Parent.utils.createTextVariant)
local NormalizeNumber = require(script.Parent.utils.normalizeNumber)
local ParseMathExpression = require(script.Parent.mathExpression.parser)

local function FormatValue(value: number): string
    return tostring(NormalizeNumber(value))
end

return CreateTextVariant<<number>>({
    InputName = "NumberValueInput",
    Format = FormatValue,
    Parse = ParseMathExpression
})
