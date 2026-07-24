--!strict

local Packages = script.Parent.Parent.Parent
local Fusion = require(Packages.fusion)

local PredictionMath = require(script.math)
local RobloxInput = require(script.robloxInput)

export type Handlers = {
    Enter: (position: Vector2) -> (),
    Move: (position: Vector2) -> (),
    Leave: () -> (),
    RootLeave: () -> (),
    ManagedChanged: (isManaged: boolean) -> (),
}

export type Registration = {
    SetPressed: (isPressed: boolean) -> (),
    Destroy: () -> (),
}

type ButtonRecord = {
    Button: GuiButton,
    Handlers: Handlers,
    Root: RootRecord?,
    RootIndex: number?,
    RegistrationOrder: number,
    Pressed: boolean,
    Managed: boolean,
    Destroying: boolean,
    Destroyed: boolean,
}

type RootRecord = {
    Root: GuiObject,
    Buttons: { ButtonRecord },
    Hovered: ButtonRecord?,
    InputCleanup: (() -> ())?,
    Managed: boolean,
    Destroyed: boolean,
}

local roots: { [GuiObject]: RootRecord } = {}
local pendingButtons: { [ButtonRecord]: true } = {}
local nextRegistrationOrder = 0

local predictionState = PredictionMath.NewState()
local hasSource = false
local currentRoot: GuiObject? = nil
local predictionActive = false
local lastPublishedPosition: Vector2? = nil

local function CallManagedChanged(
    record: ButtonRecord,
    isManaged: boolean
)
    if record.Destroyed then return end
    if record.Managed == isManaged then return end

    record.Managed = isManaged
    record.Handlers.ManagedChanged(isManaged)
end

local function LeaveRecord(record: ButtonRecord)
    if record.Destroyed then return end
    record.Handlers.Leave()
end

local function ClearHover(rootRecord: RootRecord)
    local hovered = rootRecord.Hovered
    if not hovered then return end

    rootRecord.Hovered = nil
    LeaveRecord(hovered)
end

local function RemoveFromRoot(
    record: ButtonRecord,
    shouldRemainPending: boolean
)
    local rootRecord = record.Root
    local rootIndex = record.RootIndex
    if not rootRecord or not rootIndex then return end

    if rootRecord.Hovered == record then
        rootRecord.Hovered = nil
        LeaveRecord(record)
    end

    local buttons = rootRecord.Buttons
    local lastIndex = #buttons
    local lastRecord = buttons[lastIndex]

    buttons[rootIndex] = lastRecord
    buttons[lastIndex] = nil
    if lastRecord ~= record then
        lastRecord.RootIndex = rootIndex
    end

    record.Root = nil
    record.RootIndex = nil

    if shouldRemainPending and not record.Destroyed then
        pendingButtons[record] = true
    end

    CallManagedChanged(record, false)
end

local function AddToRoot(
    record: ButtonRecord,
    rootRecord: RootRecord
)
    if record.Destroyed or rootRecord.Destroyed then return end
    if record.Root == rootRecord then return end

    if record.Root then RemoveFromRoot(record, false) end

    pendingButtons[record] = nil
    record.Root = rootRecord
    local rootIndex = #rootRecord.Buttons + 1
    record.RootIndex = rootIndex
    rootRecord.Buttons[rootIndex] = record
    CallManagedChanged(record, rootRecord.Managed)
end

local function ResolvePendingButtons(rootRecord: RootRecord)
    for record in pendingButtons do
        if record.Destroyed then
            pendingButtons[record] = nil
        elseif record.Button:IsDescendantOf(rootRecord.Root) then
            AddToRoot(record, rootRecord)
        end
    end
end

local function IsCandidate(
    record: ButtonRecord,
    rootRecord: RootRecord,
    position: Vector2
): boolean
    local button = record.Button
    if not button.Parent
        or not button.Visible
        or not button.Interactable
    then
        return false
    end

    if not PredictionMath.IsPointInRect(
        position,
        button.AbsolutePosition,
        button.AbsoluteSize
    ) then
        return false
    end

    local ancestor: Instance? = button.Parent
    while ancestor and ancestor ~= rootRecord.Root do
        if ancestor:IsA("GuiObject") then
            if not ancestor.Visible then return false end
            if ancestor.ClipsDescendants
                and not PredictionMath.IsPointInRect(
                    position,
                    ancestor.AbsolutePosition,
                    ancestor.AbsoluteSize
                )
            then
                return false
            end
        end

        ancestor = ancestor.Parent
    end

    return ancestor == rootRecord.Root
end

local function IsAbove(
    candidate: ButtonRecord,
    current: ButtonRecord?
): boolean
    if not current then return true end

    local candidateZIndex = candidate.Button.ZIndex
    local currentZIndex = current.Button.ZIndex
    return
        candidateZIndex > currentZIndex
        or (
            candidateZIndex == currentZIndex
            and candidate.RegistrationOrder > current.RegistrationOrder
        )
end

local function Publish(
    rootRecord: RootRecord,
    position: Vector2
)
    if rootRecord.Destroyed then return end

    ResolvePendingButtons(rootRecord)

    local winner: ButtonRecord? = nil
    local buttonIndex = 1
    while buttonIndex <= #rootRecord.Buttons do
        local record = rootRecord.Buttons[buttonIndex]

        if record.Destroyed then
            RemoveFromRoot(record, false)
        elseif not record.Button:IsDescendantOf(rootRecord.Root) then
            RemoveFromRoot(record, true)
        else
            if IsCandidate(record, rootRecord, position)
                and IsAbove(record, winner)
            then
                winner = record
            end

            buttonIndex += 1
        end
    end

    local previous = rootRecord.Hovered
    if previous == winner then
        if winner and not winner.Destroyed then
            winner.Handlers.Move(position)
        end
        return
    end

    if previous then
        rootRecord.Hovered = nil
        LeaveRecord(previous)
    end

    if winner
        and not winner.Destroyed
        and winner.Root == rootRecord
    then
        rootRecord.Hovered = winner
        winner.Handlers.Enter(position)
    end
end

local function ResetRoot(rootRecord: RootRecord)
    ClearHover(rootRecord)

    local pressedRecords = {}
    for _, record in rootRecord.Buttons do
        if record.Pressed and not record.Destroyed then
            record.Pressed = false
            table.insert(pressedRecords, record)
        end
    end

    for _, record in pressedRecords do
        if not record.Destroyed then
            record.Handlers.RootLeave()
        end
    end
end

local function SetRootManaged(
    rootRecord: RootRecord,
    isManaged: boolean
)
    if rootRecord.Managed == isManaged then return end
    rootRecord.Managed = isManaged

    for _, record in rootRecord.Buttons do
        CallManagedChanged(record, isManaged)
    end
end

local function OnRootLeave(root: GuiObject)
    local rootRecord = roots[root]
    if rootRecord then
        ResetRoot(rootRecord)
        SetRootManaged(rootRecord, false)
    end

    if currentRoot == root then
        hasSource = false
        currentRoot = nil
        predictionActive = false
        lastPublishedPosition = nil
    end
end

local function OnSample(
    root: GuiObject?,
    actualPosition: Vector2,
    now: number
)
    local sourceChanged = not hasSource or root ~= currentRoot
    if sourceChanged then
        if hasSource and currentRoot then
            local previousRootRecord = roots[currentRoot]
            if previousRootRecord then
                ResetRoot(previousRootRecord)
                SetRootManaged(previousRootRecord, false)
            end
        end

        hasSource = true
        currentRoot = root
        PredictionMath.Reset(predictionState, actualPosition, now)
    else
        PredictionMath.Update(predictionState, actualPosition, now)
    end

    lastPublishedPosition = nil

    if not root then
        predictionActive = false
        return
    end

    local rootRecord = roots[root]
    if not rootRecord then
        predictionActive = false
        return
    end

    SetRootManaged(rootRecord, true)

    local predictedPosition =
        PredictionMath.Predict(predictionState, now)
    if not predictedPosition then return end

    predictionActive = true
    lastPublishedPosition = predictedPosition
    Publish(rootRecord, predictedPosition)
end

local function OnStep(now: number)
    if not predictionActive then return end

    local root = currentRoot
    if not root then
        predictionActive = false
        return
    end

    local rootRecord = roots[root]
    if not rootRecord then
        predictionActive = false
        return
    end

    local predictedPosition =
        PredictionMath.Predict(predictionState, now)
    if predictedPosition
        and predictedPosition ~= lastPublishedPosition
    then
        lastPublishedPosition = predictedPosition
        Publish(rootRecord, predictedPosition)
    end

    if PredictionMath.IsSettled(predictionState, now) then
        predictionActive = false
    end
end

local InputAdapter = RobloxInput.new(OnSample, OnRootLeave, OnStep)

local function RegisterRoot(
    scope: Fusion.Scope,
    root: GuiObject
)
    assert(not roots[root], "The same cursor root cannot be registered twice")

    local rootRecord: RootRecord = {
        Root = root,
        Buttons = {},
        Hovered = nil,
        InputCleanup = nil,
        Managed = false,
        Destroyed = false,
    }
    roots[root] = rootRecord

    ResolvePendingButtons(rootRecord)
    rootRecord.InputCleanup = InputAdapter.RegisterRoot(root)

    local function Destroy()
        if rootRecord.Destroyed then return end
        rootRecord.Destroyed = true

        ResetRoot(rootRecord)
        SetRootManaged(rootRecord, false)
        roots[root] = nil

        while #rootRecord.Buttons > 0 do
            RemoveFromRoot(rootRecord.Buttons[#rootRecord.Buttons], true)
        end

        local inputCleanup = rootRecord.InputCleanup
        rootRecord.InputCleanup = nil
        if inputCleanup then inputCleanup() end
    end

    table.insert(scope, Destroy)
end

local function RegisterButton(
    scope: Fusion.Scope,
    button: GuiButton,
    handlers: Handlers
): Registration
    nextRegistrationOrder += 1

    local record: ButtonRecord = {
        Button = button,
        Handlers = handlers,
        Root = nil,
        RootIndex = nil,
        RegistrationOrder = nextRegistrationOrder,
        Pressed = false,
        Managed = false,
        Destroying = false,
        Destroyed = false,
    }
    pendingButtons[record] = true

    for _, rootRecord in roots do
        if button:IsDescendantOf(rootRecord.Root) then
            AddToRoot(record, rootRecord)
            break
        end
    end

    local function SetPressed(isPressed: boolean)
        if record.Destroyed then return end
        record.Pressed = isPressed
    end

    local function Destroy()
        if record.Destroying or record.Destroyed then return end
        record.Destroying = true
        record.Pressed = false
        pendingButtons[record] = nil

        if record.Root then RemoveFromRoot(record, false) end

        record.Destroyed = true
        record.Destroying = false
    end

    table.insert(scope, Destroy)

    return {
        SetPressed = SetPressed,
        Destroy = Destroy,
    }
end

return {
    RegisterRoot = RegisterRoot,
    RegisterButton = RegisterButton,
}
