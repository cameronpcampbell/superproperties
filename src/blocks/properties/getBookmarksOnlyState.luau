--!strict

local Packages = script.Parent.Parent.Parent.packages

local Fusion = require(Packages.fusion)
local Value = Fusion.Value

local StatesByScope: { [Fusion.Scope]: Fusion.Value<boolean> } = {}

local function GetBookmarksOnlyState(
    scope: Fusion.Scope
): Fusion.Value<boolean>
    local state = StatesByScope[scope]
    if state then return state end

    local newState = Value(scope, false)
    StatesByScope[scope] = newState

    table.insert(scope, function()
        StatesByScope[scope] = nil
    end)

    return newState
end

return GetBookmarksOnlyState
