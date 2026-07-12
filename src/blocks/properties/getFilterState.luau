--!strict

local Packages = script.Parent.Parent.Parent.packages

local Fusion = require(Packages.fusion)
local Value = Fusion.Value

local FilterStates: { [Fusion.Scope]: Fusion.Value<string?> } = {}

local function GetFilterState(scope: Fusion.Scope): Fusion.Value<string?>
    local filterState = FilterStates[scope]

    if not filterState then
        filterState = Value(scope, nil)
        FilterStates[scope] = filterState
    end

    return filterState
end

return GetFilterState
