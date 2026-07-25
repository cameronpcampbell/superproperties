--!strict

local Packages = script.Parent.Parent.Parent
local Fusion = require(Packages.fusion)

local PredictionMath = require(script.math)
local RobloxInput = require(script.robloxInput)

export type HoverHandlers = {
    Enter: (position: Vector2) -> (),
    Move: (position: Vector2) -> (),
    Leave: () -> (),
    ManagedChanged: (isManaged: boolean) -> (),
}

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

export type FrameRegistration = {
    Destroy: () -> (),
}

type TargetHandlers = {
    Enter: (position: Vector2) -> (),
    Move: (position: Vector2) -> (),
    Leave: () -> (),
    RootLeave: (() -> ())?,
    ManagedChanged: (isManaged: boolean) -> (),
}

type TargetRecord = {
    Target: GuiObject,
    Handlers: TargetHandlers,
    Root: RootRecord?,
    RootIndex: number?,
    RegistrationOrder: number,
    IsButton: boolean,
    Pressed: boolean,
    Hovered: boolean,
    HoveredByPrediction: boolean,
    Managed: boolean,
    Destroying: boolean,
    Destroyed: boolean,
}

type RootRecord = {
    Root: GuiObject,
    Targets: { TargetRecord },
    HoveredButton: TargetRecord?,
    HoveredButtonByPrediction: boolean,
    InputCleanup: (() -> ())?,
    Managed: boolean,
    Destroyed: boolean,
}

local roots: { [GuiObject]: RootRecord } = {}
local pendingTargets: { [TargetRecord]: true } = {}
local nextRegistrationOrder = 0

local PREDICTED_HOVER_RELEASE_PADDING = 10

local predictionState = PredictionMath.NewState()
local hasSource = false
local currentRoot: GuiObject? = nil
local predictionActive = false
local lastPublishedPosition: Vector2? = nil

local function CallManagedChanged(
    record: TargetRecord,
    isManaged: boolean
)
    if record.Destroyed then return end
    if record.Managed == isManaged then return end

    record.Managed = isManaged
    record.Handlers.ManagedChanged(isManaged)
end

local function LeaveRecord(record: TargetRecord)
    if record.Destroyed then return end
    record.Handlers.Leave()
end

local function ClearButtonHover(rootRecord: RootRecord)
    local hovered = rootRecord.HoveredButton
    if not hovered then return end

    rootRecord.HoveredButton = nil
    rootRecord.HoveredButtonByPrediction = false
    LeaveRecord(hovered)
end

local function RemoveFromRoot(
    record: TargetRecord,
    shouldRemainPending: boolean
)
    local rootRecord = record.Root
    local rootIndex = record.RootIndex
    if not rootRecord or not rootIndex then return end

    if rootRecord.HoveredButton == record then
        rootRecord.HoveredButton = nil
        rootRecord.HoveredButtonByPrediction = false
        LeaveRecord(record)
    elseif record.Hovered then
        record.Hovered = false
        record.HoveredByPrediction = false
        LeaveRecord(record)
    end

    local targets = rootRecord.Targets
    local lastIndex = #targets
    local lastRecord = targets[lastIndex]

    targets[rootIndex] = lastRecord
    targets[lastIndex] = nil
    if lastRecord ~= record then
        lastRecord.RootIndex = rootIndex
    end

    record.Root = nil
    record.RootIndex = nil

    if shouldRemainPending and not record.Destroyed then
        pendingTargets[record] = true
    end

    CallManagedChanged(record, false)
end

local function AddToRoot(
    record: TargetRecord,
    rootRecord: RootRecord
)
    if record.Destroyed or rootRecord.Destroyed then return end
    if record.Root == rootRecord then return end

    if record.Root then RemoveFromRoot(record, false) end

    pendingTargets[record] = nil
    record.Root = rootRecord
    local rootIndex = #rootRecord.Targets + 1
    record.RootIndex = rootIndex
    rootRecord.Targets[rootIndex] = record
    CallManagedChanged(record, rootRecord.Managed)
end

local function ResolvePendingTargets(rootRecord: RootRecord)
    for record in pendingTargets do
        if record.Destroyed then
            pendingTargets[record] = nil
        elseif record.Target:IsDescendantOf(rootRecord.Root) then
            AddToRoot(record, rootRecord)
        end
    end
end

local function IsCandidate(
    record: TargetRecord,
    rootRecord: RootRecord,
    position: Vector2,
    padding: number?
): boolean
    local target = record.Target
    if not target.Parent
        or not target.Visible
        or not target.Interactable
    then
        return false
    end

    local absoluteSize = target.AbsoluteSize
    if absoluteSize.X <= 0 or absoluteSize.Y <= 0 then
        return false
    end

    local resolvedPadding = math.max(padding or 0, 0)
    local paddingVector =
        Vector2.new(resolvedPadding, resolvedPadding)
    if not PredictionMath.IsPointInRect(
        position,
        target.AbsolutePosition - paddingVector,
        absoluteSize + paddingVector * 2
    ) then
        return false
    end

    local ancestor: Instance? = target.Parent
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
    candidate: TargetRecord,
    current: TargetRecord?
): boolean
    if not current then return true end

    local candidateZIndex = candidate.Target.ZIndex
    local currentZIndex = current.Target.ZIndex
    return
        candidateZIndex > currentZIndex
        or (
            candidateZIndex == currentZIndex
            and candidate.RegistrationOrder > current.RegistrationOrder
        )
end

local function Publish(
    rootRecord: RootRecord,
    actualPosition: Vector2,
    predictedPosition: Vector2
)
    if rootRecord.Destroyed then return end

    ResolvePendingTargets(rootRecord)

    local predictedWinner: TargetRecord? = nil
    local actualWinner: TargetRecord? = nil
    local frameRecords: { TargetRecord } = {}
    local frameCandidatePositions: { [TargetRecord]: Vector2 } = {}
    local predictedFrameCandidates: { [TargetRecord]: true } = {}
    local targetIndex = 1
    while targetIndex <= #rootRecord.Targets do
        local record = rootRecord.Targets[targetIndex]

        if record.Destroyed then
            RemoveFromRoot(record, false)
        elseif not record.Target:IsDescendantOf(rootRecord.Root) then
            RemoveFromRoot(record, true)
        else
            local isPredictedCandidate =
                IsCandidate(record, rootRecord, predictedPosition)
            local isActualCandidate =
                if actualPosition == predictedPosition then
                    isPredictedCandidate
                else
                    IsCandidate(record, rootRecord, actualPosition)

            if record.IsButton then
                if isPredictedCandidate
                    and IsAbove(record, predictedWinner)
                then
                    predictedWinner = record
                end
                if isActualCandidate and IsAbove(record, actualWinner) then
                    actualWinner = record
                end
            else
                -- Enclosing frames remain hovered while descendant buttons
                -- participate in the topmost-button selection.
                table.insert(frameRecords, record)
                if isPredictedCandidate then
                    frameCandidatePositions[record] = predictedPosition
                    predictedFrameCandidates[record] = true
                elseif isActualCandidate then
                    frameCandidatePositions[record] = actualPosition
                end
            end

            targetIndex += 1
        end
    end

    local previous = rootRecord.HoveredButton
    local winner = predictedWinner
    local winnerPosition = predictedPosition
    local winnerByPrediction = winner ~= nil

    -- Exact prediction wins first, followed by an exact physical hit.
    -- The padded bounds only retain an existing predicted hover.
    if not winner then
        winner = actualWinner
        winnerPosition = actualPosition
        winnerByPrediction = false
    end

    if not winner
        and previous
        and rootRecord.HoveredButtonByPrediction
        and not previous.Destroyed
        and previous.Root == rootRecord
        and IsCandidate(
            previous,
            rootRecord,
            predictedPosition,
            PREDICTED_HOVER_RELEASE_PADDING
        )
    then
        winner = previous
        winnerPosition = predictedPosition
        winnerByPrediction = true
    end

    if previous == winner then
        if winner and not winner.Destroyed then
            rootRecord.HoveredButtonByPrediction =
                winnerByPrediction
            winner.Handlers.Move(winnerPosition)
        end
    else
        if previous then
            rootRecord.HoveredButton = nil
            rootRecord.HoveredButtonByPrediction = false
            LeaveRecord(previous)
        end

        if winner
            and not winner.Destroyed
            and winner.Root == rootRecord
        then
            rootRecord.HoveredButton = winner
            rootRecord.HoveredButtonByPrediction =
                winnerByPrediction
            winner.Handlers.Enter(winnerPosition)
        end
    end

    for _, record in frameRecords do
        if record.Destroyed or record.Root ~= rootRecord then
            continue
        end

        local candidatePosition = frameCandidatePositions[record]
        local candidateByPrediction =
            predictedFrameCandidates[record] == true
        if not candidatePosition
            and record.Hovered
            and record.HoveredByPrediction
            and IsCandidate(
                record,
                rootRecord,
                predictedPosition,
                PREDICTED_HOVER_RELEASE_PADDING
            )
        then
            candidatePosition = predictedPosition
            candidateByPrediction = true
        end

        if candidatePosition then
            record.HoveredByPrediction =
                candidateByPrediction
            if record.Hovered then
                record.Handlers.Move(candidatePosition)
            else
                record.Hovered = true
                record.Handlers.Enter(candidatePosition)
            end
        elseif record.Hovered then
            record.Hovered = false
            record.HoveredByPrediction = false
            LeaveRecord(record)
        end
    end
end

local function ResetRoot(rootRecord: RootRecord)
    ClearButtonHover(rootRecord)

    local pressedRecords = {}
    local hoveredFrames = {}
    for _, record in rootRecord.Targets do
        if record.Hovered and not record.Destroyed then
            record.Hovered = false
            record.HoveredByPrediction = false
            table.insert(hoveredFrames, record)
        end

        if record.Pressed and not record.Destroyed then
            record.Pressed = false
            table.insert(pressedRecords, record)
        end
    end

    for _, record in hoveredFrames do
        LeaveRecord(record)
    end

    for _, record in pressedRecords do
        local rootLeave = record.Handlers.RootLeave
        if not record.Destroyed and rootLeave then
            rootLeave()
        end
    end
end

local function SetRootManaged(
    rootRecord: RootRecord,
    isManaged: boolean
)
    if rootRecord.Managed == isManaged then return end
    rootRecord.Managed = isManaged

    for _, record in rootRecord.Targets do
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
    Publish(rootRecord, actualPosition, predictedPosition)
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
    local actualPosition = predictionState.Actual
    if actualPosition
        and predictedPosition
        and predictedPosition ~= lastPublishedPosition
    then
        lastPublishedPosition = predictedPosition
        Publish(rootRecord, actualPosition, predictedPosition)
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
        Targets = {},
        HoveredButton = nil,
        HoveredButtonByPrediction = false,
        InputCleanup = nil,
        Managed = false,
        Destroyed = false,
    }
    roots[root] = rootRecord

    ResolvePendingTargets(rootRecord)
    rootRecord.InputCleanup = InputAdapter.RegisterRoot(root)

    local function Destroy()
        if rootRecord.Destroyed then return end
        rootRecord.Destroyed = true

        ResetRoot(rootRecord)
        SetRootManaged(rootRecord, false)
        roots[root] = nil

        while #rootRecord.Targets > 0 do
            RemoveFromRoot(rootRecord.Targets[#rootRecord.Targets], true)
        end

        local inputCleanup = rootRecord.InputCleanup
        rootRecord.InputCleanup = nil
        if inputCleanup then inputCleanup() end
    end

    table.insert(scope, Destroy)
end

local function RegisterTarget(
    scope: Fusion.Scope,
    target: GuiObject,
    isButton: boolean,
    handlers: TargetHandlers
): Registration
    nextRegistrationOrder += 1

    local record: TargetRecord = {
        Target = target,
        Handlers = handlers,
        Root = nil,
        RootIndex = nil,
        RegistrationOrder = nextRegistrationOrder,
        IsButton = isButton,
        Pressed = false,
        Hovered = false,
        HoveredByPrediction = false,
        Managed = false,
        Destroying = false,
        Destroyed = false,
    }
    pendingTargets[record] = true

    for _, rootRecord in roots do
        if target:IsDescendantOf(rootRecord.Root) then
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
        pendingTargets[record] = nil

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

local function RegisterButton(
    scope: Fusion.Scope,
    button: GuiButton,
    handlers: Handlers
): Registration
    return RegisterTarget(scope, button, true, handlers)
end

local function RegisterFrame(
    scope: Fusion.Scope,
    frame: Frame,
    handlers: HoverHandlers
): FrameRegistration
    return RegisterTarget(scope, frame, false, {
        Enter = handlers.Enter,
        Move = handlers.Move,
        Leave = handlers.Leave,
        RootLeave = nil,
        ManagedChanged = handlers.ManagedChanged,
    })
end

return {
    RegisterRoot = RegisterRoot,
    RegisterButton = RegisterButton,
    RegisterFrame = RegisterFrame,
}
