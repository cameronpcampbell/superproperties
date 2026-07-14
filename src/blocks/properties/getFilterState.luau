--!strict

local Packages = script.Parent.Parent.Parent.packages

local Fusion = require(Packages.fusion)
local Value = Fusion.Value

local FilterStatesByScope: { [Fusion.Scope]: Fusion.Value<string?> } = {}

local function GetFilterState(scope: Fusion.Scope): Fusion.Value<string?>
    local filterState = FilterStatesByScope[scope]
    if filterState then return filterState end

    filterState = Value(scope, nil)
    FilterStatesByScope[scope] = filterState

    table.insert(scope, function()
        FilterStatesByScope[scope] = nil
    end)

    return filterState
end

return GetFilterState
