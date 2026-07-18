--!strict

local DecimalScale = 100

local function NormalizeNumber(value: number): number
    local normalizedValue = math.round(value * DecimalScale) / DecimalScale

    return if normalizedValue == 0 then 0 else normalizedValue
end

return NormalizeNumber
