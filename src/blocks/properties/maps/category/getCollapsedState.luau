--!strict

local Packages = script.Parent.Parent.Parent.Parent.Parent.packages

local Fusion = require(Packages.fusion)
local Value = Fusion.Value

local CollapsedStatesByScope:
    { [Fusion.Scope]: { [string]: Fusion.Value<boolean> } } = {}

local function GetCollapsedState(scope: Fusion.Scope, categoryName: string)
    local collapsedStates = CollapsedStatesByScope[scope]

    if not collapsedStates then
        collapsedStates = {}
        CollapsedStatesByScope[scope] = collapsedStates

        table.insert(scope, function()
            CollapsedStatesByScope[scope] = nil
        end)
    end

    local collapsedState = collapsedStates[categoryName]
    if collapsedState then return collapsedState end

    collapsedState = Value(scope, false)
    collapsedStates[categoryName] = collapsedState

    return collapsedState
end

return GetCollapsedState
