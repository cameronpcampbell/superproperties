--!strict

local function IsValue(input: any): boolean
    return
        type(input) == "table" and
        input.type == "State" and
        input.kind == "Value"
end

return IsValue
