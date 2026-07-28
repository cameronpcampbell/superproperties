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
    Destroy: () -> (),
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
    local rootCleanups: { [() -> ()]: true } = {}
    local destroyed = false

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

    local renderConnection = RunService.PreRender:Connect(function()
        if destroyed then return end

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
        assert(not destroyed, "Cannot register a root on a destroyed input adapter")

        local rootDestroyed = false

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
        local function DestroyRoot()
            if rootDestroyed then return end
            rootDestroyed = true

            local shouldNotifyRootLeave = activeRoot == root
            if shouldNotifyRootLeave then
                activeRoot = nil
                activeRootPosition = nil
            end

            mouseEnterConnection:Disconnect()
            mouseMovedConnection:Disconnect()
            mouseLeaveConnection:Disconnect()
            destroyingConnection:Disconnect()
            rootCleanups[DestroyRoot] = nil

            if shouldNotifyRootLeave then
                local success, err = pcall(function(): boolean
                    onRootLeave(root)
                    return true
                end)
                if not success then
                    warn(`Cursor input root cleanup failed: {err}`)
                end
            end
        end

        destroyingConnection = root.Destroying:Connect(DestroyRoot)
        rootCleanups[DestroyRoot] = true
        return DestroyRoot
    end

    local function Destroy()
        if destroyed then return end
        destroyed = true

        renderConnection:Disconnect()

        for cleanup in rootCleanups do
            local success, err = pcall(function(): boolean
                cleanup()
                return true
            end)
            if not success then
                rootCleanups[cleanup] = nil
                warn(`Cursor input cleanup failed: {err}`)
            end
        end

        table.clear(rootCleanups)
        activeRoot = nil
        activeRootPosition = nil
        lastEmittedRoot = nil
        lastEmittedPosition = nil
    end

    return {
        RegisterRoot = RegisterRoot,
        Destroy = Destroy,
    }
end

return {
    new = new,
}
