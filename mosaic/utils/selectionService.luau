--!strict

local SelectionService = game:GetService("Selection")

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
    WaitingThread: thread
}

local selectionChangedEvent = Instance.new("BindableEvent")
local publishedSelection = SelectionService:Get()
local activePick: PickState? = nil

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
    if previousPick then
        activePick = nil
        task.defer(previousPick.WaitingThread)
    end

    activePick = {
        Before = SelectionService:Get(),
        WaitingThread = coroutine.running()
    }

    return coroutine.yield()
end

return SelectionServiceWrapper
