--!strict

local Packages = script.Parent.Parent.Parent.packages

local Fusion = require(Packages.fusion)
local Peek, Value = Fusion.peek, Fusion.Value

local GetBookmarksOnlyState = require(script.Parent.getBookmarksOnlyState)

local StatesByScope: { [Fusion.Scope]: Fusion.Value<boolean> } = {}

local function GetBookmarkButtonVisualState(
    scope: Fusion.Scope
): Fusion.Value<boolean>
    local state = StatesByScope[scope]
    if state then return state end

    local newState = Value(
        scope,
        Peek<<boolean>>(GetBookmarksOnlyState(scope))
    )
    StatesByScope[scope] = newState

    table.insert(scope, function()
        StatesByScope[scope] = nil
    end)

    return newState
end

return GetBookmarkButtonVisualState
