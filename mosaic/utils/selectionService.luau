--!strict

local SelectionService = game:GetService("Selection")

local INSTANCE_PICKER_CURSOR = "rbxasset://SystemCursors/Cross"

local PluginInstance = script:FindFirstAncestorOfClass("Plugin") :: Plugin?
local PluginMouse =
    if PluginInstance then PluginInstance:GetMouse() else nil

export type Wrapper = {
    SelectionChanged: RBXScriptSignal,
    SelectionThickness: number,
    Add: (self: Wrapper, instancesToAdd: { Instance }) -> (),
    Get: (self: Wrapper) -> { Instance },
    Remove: (self: Wrapper, instancesToRemove: { Instance }) -> (),
    Set: (self: Wrapper, selection: { Instance }) -> (),
    PickInstanceAsync: (self: Wrapper) -> Instance?
}

type PickState = {
    Before: { Instance },
    WaitingThread: thread,
    PreviousCursor: string?,
    ActivatedPlugin: boolean
}

local selectionChangedEvent = Instance.new("BindableEvent")
local publishedSelection = SelectionService:Get()
local activePick: PickState? = nil

local function RestorePickerState(pick: PickState)
    if PluginMouse then
        -- Do not overwrite a cursor set by another owner while the pick was
        -- active.
        if PluginMouse.Icon == INSTANCE_PICKER_CURSOR then
            PluginMouse.Icon = pick.PreviousCursor or ""
        end
    end

    if
        pick.ActivatedPlugin
        and PluginInstance
        and PluginInstance:IsActivated()
    then
        PluginInstance:Deactivate()
    end
end

local function SelectionsEqual(
    left: { Instance },
    right: { Instance }
): boolean
    if #left ~= #right then return false end

    for index, instance in left do
        if instance ~= right[index] then return false end
    end

    return true
end

local function FindPickedInstance(
    before: { Instance },
    after: { Instance }
): Instance?
    local previouslySelected = {} :: { [Instance]: boolean }

    for _, instance in before do
        previouslySelected[instance] = true
    end

    for _, instance in after do
        if not previouslySelected[instance] then
            return instance
        end
    end

    return after[1]
end

SelectionService.SelectionChanged:Connect(function()
    local currentSelection = SelectionService:Get()

    -- Ignore redundant signals, including the selection restoration performed
    -- after a pick. Check this before activePick so a deferred restoration
    -- cannot accidentally complete a newer pick.
    if SelectionsEqual(currentSelection, publishedSelection) then return end

    local pick = activePick
    if pick then
        local pickedInstance =
            FindPickedInstance(pick.Before, currentSelection)

        -- Clear the pick before restoring the selection so the restoration
        -- cannot be interpreted as another picked instance.
        activePick = nil
        SelectionService:Set(pick.Before)
        RestorePickerState(pick)
        task.defer(pick.WaitingThread, pickedInstance)
        return
    end

    publishedSelection = table.clone(currentSelection)
    selectionChangedEvent:Fire()
end)

local SelectionServiceWrapper: Wrapper = setmetatable({
    SelectionChanged = selectionChangedEvent.Event
}, {
    __index = function(_, key)
        if key == "SelectionThickness" then
            return SelectionService.SelectionThickness
        end

        return nil
    end
}) :: any

function SelectionServiceWrapper:Add(instancesToAdd: { Instance })
    SelectionService:Add(instancesToAdd)
end

function SelectionServiceWrapper:Get(): { Instance }
    return SelectionService:Get()
end

function SelectionServiceWrapper:Remove(instancesToRemove: { Instance })
    SelectionService:Remove(instancesToRemove)
end

function SelectionServiceWrapper:Set(selection: { Instance })
    SelectionService:Set(selection)
end

function SelectionServiceWrapper:PickInstanceAsync(): Instance?
    local previousPick = activePick
    local previousCursor =
        if previousPick then previousPick.PreviousCursor
        else if PluginMouse then PluginMouse.Icon
        else nil
    local activatedPlugin =
        if previousPick then previousPick.ActivatedPlugin
        else false

    if previousPick then
        activePick = nil
        task.defer(previousPick.WaitingThread)
    end

    if PluginInstance and not PluginInstance:IsActivated() then
        PluginInstance:Activate(false)
        activatedPlugin = true
    end

    activePick = {
        Before = SelectionService:Get(),
        WaitingThread = coroutine.running(),
        PreviousCursor = previousCursor,
        ActivatedPlugin = activatedPlugin
    }

    if PluginMouse then
        PluginMouse.Icon = INSTANCE_PICKER_CURSOR
    end

    return coroutine.yield()
end

if PluginInstance then
    PluginInstance.Unloading:Connect(function()
        local pick = activePick
        if not pick then return end

        activePick = nil
        RestorePickerState(pick)
        task.defer(pick.WaitingThread)
    end)
end

return SelectionServiceWrapper
