--!strict

local RunService = game:GetService("RunService")

export type SampleCallback = (
    root: GuiObject?,
    position: Vector2,
    now: number
) -> ()

export type RootLeaveCallback = (root: GuiObject) -> ()
export type StepCallback = (now: number) -> ()

export type Adapter = {
    RegisterRoot: (root: GuiObject) -> (() -> ()),
}

local PluginInstance =
    script:FindFirstAncestorOfClass("Plugin") :: Plugin?
local PluginMouse =
    if PluginInstance then PluginInstance:GetMouse() else nil

local function new(
    onSample: SampleCallback,
    onRootLeave: RootLeaveCallback,
    onStep: StepCallback
): Adapter
    local activeRoot: GuiObject? = nil
    local activeRootPosition: Vector2? = nil
    local hasEmittedSample = false
    local lastEmittedRoot: GuiObject? = nil
    local lastEmittedPosition: Vector2? = nil

    local function SetActiveRoot(
        root: GuiObject,
        x: number,
        y: number
    )
        local previousRoot = activeRoot
        if previousRoot and previousRoot ~= root then
            onRootLeave(previousRoot)
        end

        activeRoot = root
        activeRootPosition = Vector2.new(x, y)
    end

    local function ClearActiveRoot(root: GuiObject)
        if activeRoot ~= root then return end

        activeRoot = nil
        activeRootPosition = nil
        onRootLeave(root)
    end

    RunService.PreRender:Connect(function()
        local now = os.clock()
        local root = activeRoot
        local position =
            if root then activeRootPosition
            else if PluginMouse then
                Vector2.new(PluginMouse.X, PluginMouse.Y)
            else nil

        if position
            and (
                not hasEmittedSample
                or root ~= lastEmittedRoot
                or position ~= lastEmittedPosition
            )
        then
            hasEmittedSample = true
            lastEmittedRoot = root
            lastEmittedPosition = position
            onSample(root, position, now)
        else
            onStep(now)
        end
    end)

    local function RegisterRoot(root: GuiObject): () -> ()
        local destroyed = false

        local mouseEnterConnection = root.MouseEnter:Connect(function(x, y)
            SetActiveRoot(root, x, y)
        end)
        local mouseMovedConnection = root.MouseMoved:Connect(function(x, y)
            SetActiveRoot(root, x, y)
        end)
        local mouseLeaveConnection = root.MouseLeave:Connect(function()
            ClearActiveRoot(root)
        end)

        local destroyingConnection: RBXScriptConnection
        local function Destroy()
            if destroyed then return end
            destroyed = true

            ClearActiveRoot(root)
            mouseEnterConnection:Disconnect()
            mouseMovedConnection:Disconnect()
            mouseLeaveConnection:Disconnect()
            destroyingConnection:Disconnect()
        end

        destroyingConnection = root.Destroying:Connect(Destroy)
        return Destroy
    end

    return {
        RegisterRoot = RegisterRoot,
    }
end

return {
    new = new,
}
