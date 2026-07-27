--!strict

local ChangeHistoryService = game:GetService("ChangeHistoryService")

local GetProperties = require(script.Parent.Parent.Parent.getProperties)
type PropertyPlan = GetProperties.PropertyPlan

export type Target = {
    Instance: Instance,
    Plan: PropertyPlan
}

type PendingWrite = {
    Target: Target,
    OriginalValue: any?,
    NextValue: any?
}

local function GetInstanceLabel(instance: Instance): string
    local success, fullName = pcall(instance.GetFullName, instance)
    return if success then fullName else instance.Name
end

local function RollBack(written: { PendingWrite }): string?
    local rollbackErrors = {} :: { string }

    for writeIdx = #written, 1, -1 do
        local pending = written[writeIdx]
        local success, result = GetProperties.WriteProperty(
            pending.Target.Instance,
            pending.Target.Plan,
            pending.OriginalValue
        )

        if not success then
            table.insert(
                rollbackErrors,
                `{GetInstanceLabel(pending.Target.Instance)}: {result}`
            )
        end
    end

    if #rollbackErrors == 0 then return nil end
    return ` Rollback also failed for {table.concat(rollbackErrors, "; ")}.`
end

return function(
    targets: { Target },
    transformValue: (currentValue: any?) -> any?
): (boolean, string?)
    local pendingWrites = {} :: { PendingWrite }

    for _, target in targets do
        local readSuccess, currentValue =
            GetProperties.ReadProperty(target.Instance, target.Plan)
        if not readSuccess then
            return false,
                `Could not read {target.Plan.Name} on {GetInstanceLabel(target.Instance)}: {currentValue}`
        end

        local transformSuccess, nextValue =
            pcall(transformValue, currentValue)
        if not transformSuccess then
            return false,
                `Could not prepare {target.Plan.Name} on {GetInstanceLabel(target.Instance)}: {nextValue}`
        end
        if currentValue == nextValue then continue end

        table.insert(pendingWrites, {
            Target = target,
            OriginalValue = currentValue,
            NextValue = nextValue
        })
    end

    if #pendingWrites == 0 then return true, nil end

    local propertyName = pendingWrites[1].Target.Plan.Name
    local beginSuccess, recording = pcall(
        ChangeHistoryService.TryBeginRecording,
        ChangeHistoryService,
        "SuperProperties.SetProperty",
        `Set {propertyName}`
    )
    if not beginSuccess then
        return false, `Could not start an undo recording: {recording}`
    end
    if not recording then
        return false, "Could not start an undo recording."
    end

    local written = {} :: { PendingWrite }
    local writeError: string? = nil

    for _, pending in pendingWrites do
        local success, result = GetProperties.WriteProperty(
            pending.Target.Instance,
            pending.Target.Plan,
            pending.NextValue
        )
        if not success then
            writeError =
                `Could not set {propertyName} on {GetInstanceLabel(pending.Target.Instance)}: {result}`
            break
        end

        table.insert(written, pending)
    end

    local rollbackError =
        if writeError then RollBack(written) else nil
    local operation =
        if writeError then Enum.FinishRecordingOperation.Cancel
        else Enum.FinishRecordingOperation.Commit
    local finishSuccess, finishResult = pcall(
        ChangeHistoryService.FinishRecording,
        ChangeHistoryService,
        recording,
        operation,
        nil
    )

    if not finishSuccess then
        return false, `Could not finish the undo recording: {finishResult}`
    end
    if writeError then
        local errorMessage = writeError
        if rollbackError then errorMessage ..= rollbackError end
        return false, errorMessage
    end

    return true, nil
end
