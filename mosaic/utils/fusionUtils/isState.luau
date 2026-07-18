--!strict

local function IsState(input: any): boolean
    return
        type(input) == "table" and
        input.type == "State"
end

local function IsValue(input: any): boolean
    return IsState(input) and input.kind == "Value"
end

return {
    IsState = IsState,
    IsValue = IsValue
}
