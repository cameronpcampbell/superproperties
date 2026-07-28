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

export type TargetOptions = {
    IsAvailable: (() -> boolean)?,
}

export type Registration = {
    SetPressed: (isPressed: boolean) -> (),
    Destroy: () -> (),
}

export type FrameRegistration = {
    Destroy: () -> (),
}

export type InputRegistration = {
    Destroy: () -> (),
}

type TargetHandlers = Handlers

type TargetRecord = {
    Target: GuiObject,
    Handlers: TargetHandlers,
    Root: RootRecord?,
    RootIndex: number?,
    RegistrationOrder: number,
    IsExclusiveTarget: boolean,
    IsAvailable: (() -> boolean)?,
    Pressed: boolean,
    Hovered: boolean,
    HoveredByPrediction: boolean,
    Managed: boolean,
    Destroying: boolean,
    Destroyed: boolean,
}

type TargetHit = {
    Position: Vector2,
    Fraction: number,
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

local function Noop() end

local PREDICTION_CONFIG: PredictionMath.Config =
    PredictionMath.DefaultConfig
-- For temporary visual stress testing, use
-- PredictionMath.DebugOverpredictionConfig above.
local PREDICTED_HOVER_ACQUIRE_INSET = 3
local PREDICTED_HOVER_RELEASE_PADDING = 10
local PREDICTED_TARGET_SWITCH_MARGIN = 0.012

local predictionState = PredictionMath.NewState()
local hasSource = false
local currentRoot: GuiObject? = nil
local predictionActive = false

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

local function IsTargetAvailable(
    record: TargetRecord,
    rootRecord: RootRecord
): boolean
    local target = record.Target
    if not target.Parent or not target.Visible then
        return false
    end

    local resolveAvailability = record.IsAvailable
    local isAvailable =
        if resolveAvailability then resolveAvailability()
        else target.Interactable
    if not isAvailable then return false end

    local absoluteSize = target.AbsoluteSize
    if absoluteSize.X <= 0 or absoluteSize.Y <= 0 then
        return false
    end

    local ancestor: Instance? = target.Parent
    while ancestor and ancestor ~= rootRecord.Root do
        if ancestor:IsA("GuiObject") and not ancestor.Visible then
            return false
        end
        ancestor = ancestor.Parent
    end

    return ancestor == rootRecord.Root
end

local function IsCandidate(
    record: TargetRecord,
    rootRecord: RootRecord,
    position: Vector2,
    padding: number?
): boolean
    if not IsTargetAvailable(record, rootRecord) then
        return false
    end

    local target = record.Target
    local absoluteSize = target.AbsoluteSize
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

local function IntersectRects(
    firstPosition: Vector2,
    firstSize: Vector2,
    secondPosition: Vector2,
    secondSize: Vector2
): (Vector2?, Vector2?)
    local minimum = Vector2.new(
        math.max(firstPosition.X, secondPosition.X),
        math.max(firstPosition.Y, secondPosition.Y)
    )
    local maximum = Vector2.new(
        math.min(
            firstPosition.X + firstSize.X,
            secondPosition.X + secondSize.X
        ),
        math.min(
            firstPosition.Y + firstSize.Y,
            secondPosition.Y + secondSize.Y
        )
    )
    local size = maximum - minimum
    if size.X <= 0 or size.Y <= 0 then
        return nil, nil
    end

    return minimum, size
end

local function GetEffectiveTargetRect(
    record: TargetRecord,
    rootRecord: RootRecord,
    margin: number
): (Vector2?, Vector2?)
    if not IsTargetAvailable(record, rootRecord) then
        return nil, nil
    end

    local marginVector = Vector2.new(margin, margin)
    local position =
        record.Target.AbsolutePosition - marginVector
    local size =
        record.Target.AbsoluteSize + marginVector * 2
    if size.X <= 0 or size.Y <= 0 then
        return nil, nil
    end

    local ancestor: Instance? = record.Target.Parent
    while ancestor and ancestor ~= rootRecord.Root do
        if ancestor:IsA("GuiObject") and ancestor.ClipsDescendants then
            local clippedPosition, clippedSize = IntersectRects(
                position,
                size,
                ancestor.AbsolutePosition,
                ancestor.AbsoluteSize
            )
            if not clippedPosition or not clippedSize then
                return nil, nil
            end
            position = clippedPosition
            size = clippedSize
        end
        ancestor = ancestor.Parent
    end

    return position, size
end

local function ClampPointToTarget(
    point: Vector2,
    target: GuiObject
): Vector2
    local position = target.AbsolutePosition
    local maximum = position + target.AbsoluteSize
    return Vector2.new(
        math.clamp(point.X, position.X, maximum.X),
        math.clamp(point.Y, position.Y, maximum.Y)
    )
end

local function GetTrajectoryHit(
    record: TargetRecord,
    rootRecord: RootRecord,
    actualPosition: Vector2,
    predictedPosition: Vector2,
    margin: number
): TargetHit?
    local position, size =
        GetEffectiveTargetRect(record, rootRecord, margin)
    if not position or not size then return nil end

    local hit = PredictionMath.IntersectSegmentRect(
        actualPosition,
        predictedPosition,
        position,
        size
    )
    if not hit then return nil end

    return {
        Position = ClampPointToTarget(
            predictedPosition,
            record.Target
        ),
        Fraction = hit.Fraction,
    }
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
    prediction: PredictionMath.Prediction
)
    if rootRecord.Destroyed then return end

    ResolvePendingTargets(rootRecord)

    local predictedPosition = prediction.Position
    local predictionEligible =
        prediction.Confidence >= PREDICTION_CONFIG.MinConfidence
        and predictedPosition ~= actualPosition
    local predictedWinner: TargetRecord? = nil
    local predictedWinnerHit: TargetHit? = nil
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
            local isActualCandidate =
                IsCandidate(record, rootRecord, actualPosition)
            local predictedHit =
                if predictionEligible then
                    GetTrajectoryHit(
                        record,
                        rootRecord,
                        actualPosition,
                        predictedPosition,
                        -PREDICTED_HOVER_ACQUIRE_INSET
                    )
                else
                    nil

            if record.IsExclusiveTarget then
                if predictedHit
                    and (
                        not predictedWinnerHit
                        or predictedHit.Fraction
                            < predictedWinnerHit.Fraction
                        or (
                            math.abs(
                                predictedHit.Fraction
                                    - predictedWinnerHit.Fraction
                            ) <= 1e-6
                            and IsAbove(record, predictedWinner)
                        )
                    )
                then
                    predictedWinner = record
                    predictedWinnerHit = predictedHit
                end
                if isActualCandidate and IsAbove(record, actualWinner) then
                    actualWinner = record
                end
            else
                -- Enclosing frames remain hovered while descendant buttons
                -- participate in the topmost-button selection.
                table.insert(frameRecords, record)
                if isActualCandidate then
                    frameCandidatePositions[record] = actualPosition
                elseif predictedHit then
                    frameCandidatePositions[record] =
                        predictedHit.Position
                    predictedFrameCandidates[record] = true
                elseif predictionEligible
                    and record.Hovered
                    and record.HoveredByPrediction
                then
                    local retainedHit = GetTrajectoryHit(
                        record,
                        rootRecord,
                        actualPosition,
                        predictedPosition,
                        PREDICTED_HOVER_RELEASE_PADDING
                    )
                    if retainedHit then
                        frameCandidatePositions[record] =
                            retainedHit.Position
                        predictedFrameCandidates[record] = true
                    end
                end
            end

            targetIndex += 1
        end
    end

    local previous = rootRecord.HoveredButton
    local winner = actualWinner
    local winnerPosition = actualPosition
    local winnerByPrediction = false

    -- The physical cursor is authoritative. Prediction only fills the empty
    -- space before it reaches an interactable target.
    if not winner and predictionEligible then
        local retainedHit =
            if previous
                and rootRecord.HoveredButtonByPrediction
                and not previous.Destroyed
                and previous.Root == rootRecord
            then
                GetTrajectoryHit(
                    previous,
                    rootRecord,
                    actualPosition,
                    predictedPosition,
                    PREDICTED_HOVER_RELEASE_PADDING
                )
            else
                nil

        if retainedHit then
            winner = previous
            winnerPosition = retainedHit.Position
            winnerByPrediction = true

            if predictedWinner == previous and predictedWinnerHit then
                winnerPosition = predictedWinnerHit.Position
            elseif predictedWinner
                and predictedWinnerHit
                and (
                    predictedWinnerHit.Fraction
                        * prediction.Horizon
                    + PREDICTED_TARGET_SWITCH_MARGIN
                    < retainedHit.Fraction
                        * prediction.Horizon
                )
            then
                winner = predictedWinner
                winnerPosition = predictedWinnerHit.Position
            end
        elseif predictedWinner and predictedWinnerHit then
            winner = predictedWinner
            winnerPosition = predictedWinnerHit.Position
            winnerByPrediction = true
        end
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

    local pressedRecords: { TargetRecord } = {}
    local hoveredFrames: { TargetRecord } = {}
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
        PredictionMath.Update(
            predictionState,
            actualPosition,
            now,
            PREDICTION_CONFIG
        )
    end

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

    local prediction = PredictionMath.Predict(
        predictionState,
        now,
        PREDICTION_CONFIG
    )
    if not prediction then return end

    predictionActive = not PredictionMath.IsSettled(
        predictionState,
        now,
        PREDICTION_CONFIG
    )
    Publish(rootRecord, actualPosition, prediction)
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

    local prediction = PredictionMath.Predict(
        predictionState,
        now,
        PREDICTION_CONFIG
    )
    local actualPosition = predictionState.Actual
    if actualPosition and prediction then
        Publish(rootRecord, actualPosition, prediction)
    end

    if PredictionMath.IsSettled(
        predictionState,
        now,
        PREDICTION_CONFIG
    ) then
        predictionActive = false
    end
end

local inputAdapter: RobloxInput.Adapter? = nil

local function GetInputAdapter(): RobloxInput.Adapter
    local adapter = inputAdapter
    if adapter then return adapter end

    local createdAdapter = RobloxInput.new(OnSample, OnRootLeave, OnStep)
    inputAdapter = createdAdapter
    return createdAdapter
end

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

    local function Destroy()
        if rootRecord.Destroyed then return end
        rootRecord.Destroyed = true

        roots[root] = nil

        local inputCleanup = rootRecord.InputCleanup
        rootRecord.InputCleanup = nil
        if inputCleanup then
            local success, err = pcall(function(): boolean
                inputCleanup()
                return true
            end)
            if not success then
                warn(`Cursor root input cleanup failed: {err}`)
            end
        end

        if next(roots) == nil then
            local adapter = inputAdapter
            inputAdapter = nil
            if adapter then
                local success, err = pcall(function(): boolean
                    adapter.Destroy()
                    return true
                end)
                if not success then
                    warn(`Cursor adapter cleanup failed: {err}`)
                end
            end
        end

        local success, err = pcall(function()
            ResetRoot(rootRecord)
            SetRootManaged(rootRecord, false)

            while #rootRecord.Targets > 0 do
                RemoveFromRoot(rootRecord.Targets[#rootRecord.Targets], true)
            end
        end)
        if not success then
            warn(`Cursor root bookkeeping cleanup failed: {err}`)
        end
    end

    table.insert(scope, Destroy)

    ResolvePendingTargets(rootRecord)
    rootRecord.InputCleanup = GetInputAdapter().RegisterRoot(root)
end

local function RegisterTarget(
    scope: Fusion.Scope,
    target: GuiObject,
    isExclusiveTarget: boolean,
    handlers: TargetHandlers,
    options: TargetOptions?
): Registration
    nextRegistrationOrder += 1

    local record: TargetRecord = {
        Target = target,
        Handlers = handlers,
        Root = nil,
        RootIndex = nil,
        RegistrationOrder = nextRegistrationOrder,
        IsExclusiveTarget = isExclusiveTarget,
        IsAvailable =
            if options then options.IsAvailable else nil,
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
        -- Teardown only removes predictor bookkeeping. Closing the callback
        -- gate first prevents a synthetic Leave from mutating UI state while
        -- its Fusion scope is already being cleaned up.
        record.Destroyed = true
        record.Pressed = false
        pendingTargets[record] = nil

        if record.Root then RemoveFromRoot(record, false) end

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
    handlers: Handlers,
    options: TargetOptions?
): Registration
    return RegisterTarget(scope, button, true, handlers, options)
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
        RootLeave = Noop,
        ManagedChanged = handlers.ManagedChanged,
    })
end

local function RegisterInput(
    scope: Fusion.Scope,
    input: TextBox,
    handlers: HoverHandlers
): InputRegistration
    return RegisterTarget(scope, input, true, {
        Enter = handlers.Enter,
        Move = handlers.Move,
        Leave = handlers.Leave,
        RootLeave = Noop,
        ManagedChanged = handlers.ManagedChanged,
    })
end

return {
    RegisterRoot = RegisterRoot,
    RegisterButton = RegisterButton,
    RegisterFrame = RegisterFrame,
    RegisterInput = RegisterInput,
}
