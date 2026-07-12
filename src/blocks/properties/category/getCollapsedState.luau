--!strict

local Packages = script.Parent.Parent.Parent.Parent.packages

local Fusion = require(Packages.fusion)
local Value = Fusion.Value

local MapCollapsedStates: { [string]: Fusion.Value<boolean> } = {}

local function GetCollapsedState(scope: Fusion.Scope, categoryName: string)
    local collapsedState = MapCollapsedStates[categoryName]

    if not collapsedState then
        collapsedState = Value(scope, false)
        MapCollapsedStates[categoryName] = collapsedState
    end

    return collapsedState
end

return GetCollapsedState
