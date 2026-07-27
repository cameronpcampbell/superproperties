--!strict

local ChangeHistoryService = game:GetService("ChangeHistoryService")

type PendingWrite = {
    Instance: Instance,
    OriginalValue: any?,
    NextValue: any?
}

local function SetAttribute(
    instance: Instance,
    attributeName: string,
    value: any?
): (boolean, any?)
    return pcall(instance.SetAttribute, instance, attributeName, value)
end

return function(
    instances: { Instance },
    attributeName: string,
    transformValue: (currentValue: any?) -> any?
): (boolean, string?)
    local pendingWrites = {} :: { PendingWrite }

    for _, instance in instances do
        local currentValue = instance:GetAttribute(attributeName)
        local transformSuccess, nextValue =
            pcall(transformValue, currentValue)
        if not transformSuccess then return false, tostring(nextValue) end
        if currentValue == nextValue then continue end

        table.insert(pendingWrites, {
            Instance = instance,
            OriginalValue = currentValue,
            NextValue = nextValue
        })
    end

    if #pendingWrites == 0 then return true, nil end

    local beginSuccess, recording = pcall(
        ChangeHistoryService.TryBeginRecording,
        ChangeHistoryService,
        "SuperProperties.SetAttribute",
        `Set {attributeName}`
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
        local success, result = SetAttribute(
            pending.Instance,
            attributeName,
            pending.NextValue
        )
        if not success then
            writeError = tostring(result)
            break
        end
        table.insert(written, pending)
    end

    if writeError then
        for writeIdx = #written, 1, -1 do
            local pending = written[writeIdx]
            SetAttribute(
                pending.Instance,
                attributeName,
                pending.OriginalValue
            )
        end
    end

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
    if writeError then return false, writeError end

    return true, nil
end
