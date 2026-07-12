--!strict
--!nolint LocalShadow

local Packages = script.Parent.Parent.Parent.Parent

local Fusion = require(Packages.fusion)
local Value = Fusion.Value

local IsValue = require(script.Parent.isValue)

local function CoerceToValue<S>(scope: Fusion.Scope, input: any): Fusion.Value<S>
    if IsValue(input) then return input end

    return Value(scope, input)
end

return CoerceToValue
