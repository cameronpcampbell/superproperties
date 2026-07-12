--!strict

local Packages = script.Parent.Parent.Parent.Parent.Parent.packages

local Fusion = require(Packages.fusion)
local Value = Fusion.Value

local MapCollapsedStates:
    { [Fusion.Scope]: { [string]: Fusion.Value<boolean> } } = {}

local function GetCollapsedState(scope: Fusion.Scope, categoryName: string)
    local collapsedStatesForScope = MapCollapsedStates[scope]

    if not collapsedStatesForScope then
        collapsedStatesForScope = {}
        MapCollapsedStates[scope] = collapsedStatesForScope

        local collapsedState = Value(scope, false)
        collapsedStatesForScope[categoryName] = collapsedState

        return collapsedState

    else
        local collapsedState = collapsedStatesForScope[categoryName]

        if not collapsedState then
            collapsedState = Value(scope, false)
            collapsedStatesForScope[categoryName] = collapsedState
        end

        return collapsedState
    end
end

return GetCollapsedState
