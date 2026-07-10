--!strict
--!nolint LocalShadow

local Packages = script.Parent.Parent.Parent.Parent.packages

local Fusion = require(Packages.fusion)
local Value = Fusion.Value

local function CoerceToValue<S>(scope: Fusion.Scope, input: any): Fusion.Value<S>
    if
        type(input) == "table" and
        (input :: { [any]: any }).type == "State" and
        (input :: { [any]: any }).kind == "Value"
    then
        return input
    end

    return Value(scope, input)
end

return CoerceToValue
