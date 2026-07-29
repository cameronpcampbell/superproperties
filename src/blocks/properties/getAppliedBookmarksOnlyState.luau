--!strict

local RunService = game:GetService("RunService")

local Packages = script.Parent.Parent.Parent.packages

local Fusion = require(Packages.fusion)
local Observer, Peek, Value =
    Fusion.Observer, Fusion.peek, Fusion.Value

local GetBookmarksOnlyState = require(script.Parent.getBookmarksOnlyState)

local StatesByScope: { [Fusion.Scope]: Fusion.Value<boolean> } = {}

local function GetAppliedBookmarksOnlyState(
    scope: Fusion.Scope
): Fusion.Value<boolean>
    local state = StatesByScope[scope]
    if state then return state end

    local requestedState = GetBookmarksOnlyState(scope)
    local appliedState = Value(
        scope,
        Peek<<boolean>>(requestedState)
    )
    StatesByScope[scope] = appliedState

    local revision = 0
    local alive = true

    Observer(scope, requestedState):onChange(function()
        revision += 1
        local queuedRevision = revision
        local requested = Peek<<boolean>>(requestedState)

        if requested then
            appliedState:set(true)
            return
        end

        task.spawn(function()
            -- Let the input button paint its outline before expanding every
            -- property map. Two heartbeats guarantee a render opportunity
            -- between the visual state change and the expensive refresh.
            RunService.Heartbeat:Wait()
            RunService.Heartbeat:Wait()

            if not alive
                or revision ~= queuedRevision
                or Peek<<boolean>>(requestedState)
            then
                return
            end

            appliedState:set(false)
        end)
    end)

    table.insert(scope, function()
        alive = false
        StatesByScope[scope] = nil
    end)

    return appliedState
end

return GetAppliedBookmarksOnlyState
