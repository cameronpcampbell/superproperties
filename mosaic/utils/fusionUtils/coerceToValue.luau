--!strict
--!nolint LocalShadow

local Packages = script.Parent.Parent.Parent.Parent

local Fusion = require(Packages.fusion)
local Value = Fusion.Value

local IsState = require(script.Parent.isState)
local IsValue = IsState.IsValue

local function CoerceToValue<S>(scope: Fusion.Scope, input: any): Fusion.Value<S>
    if IsValue(input) then return input end

    return Value(scope, input)
end

return CoerceToValue
