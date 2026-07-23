--!strict

local Packages = script.Parent.Parent.Parent
local Fusion = require(Packages.fusion)

local FusionUtils = require(script.Parent.fusionUtils)
local ScopedData = FusionUtils.ScopedData

export type EventName = "MouseEnter" | "MouseLeave" | "MouseMove"



export type AddEvent =
    ((
        scope: Fusion.Scope,
        name: "MouseEnter" | "MouseLeave" | "MouseMove",
        callback: (...any) -> ()
    ) -> (() -> ()))

type EventCallback = (...any) -> ()

type ConnectionRecord = {
    Connection: RBXScriptConnection,
    Destroyed: boolean,
    Destroy: () -> (),
}

type RootRecord = {
    Frame: Frame,
    Connections: { [ConnectionRecord]: true },
    DestroyingConnection: RBXScriptConnection?,
    Destroyed: boolean,
}

type EventRecord = {
    Name: EventName,
    Callback: EventCallback,
    Connections: { [ConnectionRecord]: true },
    Destroyed: boolean,
}

type RootContext = {
    Parent: RootContext?,
    Children: { [RootContext]: true },
    Roots: { [RootRecord]: true },
    Events: { [EventRecord]: true },
    Destroyed: boolean,
}

local RootRecordsByFrame = setmetatable({}, {
    __mode = "k",
}) :: { [Frame]: RootRecord }

local function UpdateContextParent(
    context: RootContext,
    parent: RootContext?
)
    if parent and parent.Destroyed then parent = nil end
    if context.Parent == parent then return end

    local previousParent = context.Parent
    if previousParent then previousParent.Children[context] = nil end

    context.Parent = parent
    if parent then parent.Children[context] = true end
end

local function DestroyContext(context: RootContext)
    if context.Destroyed then return end
    context.Destroyed = true

    local parent = context.Parent
    if parent then parent.Children[context] = nil end

    for child in context.Children do
        child.Parent = nil
    end

    table.clear(context.Children)
    table.clear(context.Roots)
    table.clear(context.Events)
end

local function GetOrCreateContext(scope: Fusion.Scope): RootContext
    return ScopedData(scope, "RootContext", {
        Mode = "Scoped",
        Create = function(parent: RootContext?)
            if parent and parent.Destroyed then parent = nil end

            local context: RootContext = {
                Parent = nil,
                Children = {},
                Roots = {},
                Events = {},
                Destroyed = false,
            }

            UpdateContextParent(context, parent)

            return context
        end,
        Destroy = DestroyContext,
        UpdateParent = UpdateContextParent,
    })
end

local function Connect(root: RootRecord, event: EventRecord)
    if root.Destroyed or event.Destroyed then return end

    local connection: RBXScriptConnection

    if event.Name == "MouseEnter" then
        connection = root.Frame.MouseEnter:Connect(function()
            if not event.Destroyed then event.Callback() end
        end)

    elseif event.Name == "MouseLeave" then
        connection = root.Frame.MouseLeave:Connect(function()
            if not event.Destroyed then event.Callback() end
        end)

    else
        connection = root.Frame.MouseMoved:Connect(function(x: number, y: number)
            if not event.Destroyed then event.Callback(x, y) end
        end)
    end

    local record: ConnectionRecord
    record = {
        Connection = connection,
        Destroyed = false,
        Destroy = function()
            if record.Destroyed then return end
            record.Destroyed = true

            root.Connections[record] = nil
            event.Connections[record] = nil
            record.Connection:Disconnect()
        end,
    }

    root.Connections[record] = true
    event.Connections[record] = true
end

local function DestroyConnections(
    connections: { [ConnectionRecord]: true }
)
    for connection in connections do
        connection.Destroy()
    end
end

local function DestroyRootRecord(
    context: RootContext,
    root: RootRecord
)
    if root.Destroyed then return end
    root.Destroyed = true

    context.Roots[root] = nil
    RootRecordsByFrame[root.Frame] = nil

    DestroyConnections(root.Connections)

    local destroyingConnection = root.DestroyingConnection
    root.DestroyingConnection = nil
    if destroyingConnection then destroyingConnection:Disconnect() end
end

local function DestroyEventRecord(
    context: RootContext,
    event: EventRecord
)
    if event.Destroyed then return end
    event.Destroyed = true

    context.Events[event] = nil
    DestroyConnections(event.Connections)
end

local function ConnectRootToDescendantEvents(
    context: RootContext,
    root: RootRecord
)
    if context.Destroyed then return end

    for event in context.Events do
        Connect(root, event)
    end

    for child in context.Children do
        ConnectRootToDescendantEvents(child, root)
    end
end

local function ConnectEventToInheritedRoots(
    context: RootContext,
    event: EventRecord
)
    local current: RootContext? = context

    while current do
        for root in current.Roots do
            Connect(root, event)
        end

        current = current.Parent
    end
end

local function AddRoot(scope: Fusion.Scope, root: Frame): ()
    local existing = RootRecordsByFrame[root]
    assert(
        existing == nil or existing.Destroyed,
        "The same root Frame cannot be added more than once"
    )

    local context = GetOrCreateContext(scope)
    local record: RootRecord = {
        Frame = root,
        Connections = {},
        DestroyingConnection = nil,
        Destroyed = false,
    }

    context.Roots[record] = true
    RootRecordsByFrame[root] = record

    record.DestroyingConnection = root.Destroying:Connect(function()
        DestroyRootRecord(context, record)
    end)

    ConnectRootToDescendantEvents(context, record)

    table.insert(scope, function()
        DestroyRootRecord(context, record)
    end)
end

local function AddEvent(
    scope: Fusion.Scope,
    name: EventName,
    callback: (() -> ()) | ((x: number, y: number) -> ())
): () -> ()
    local context = GetOrCreateContext(scope)
    local record: EventRecord = {
        Name = name,
        Callback = callback :: any,
        Connections = {},
        Destroyed = false,
    }

    context.Events[record] = true
    ConnectEventToInheritedRoots(context, record)

    local function destroy()
        DestroyEventRecord(context, record)
    end

    table.insert(scope, destroy)
    return destroy
end

return {
    AddRoot = AddRoot,
    AddEvent = AddEvent :: AddEvent,
}
