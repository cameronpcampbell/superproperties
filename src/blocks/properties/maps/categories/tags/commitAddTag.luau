--!strict

local ChangeHistoryService = game:GetService("ChangeHistoryService")

return function(
    instances: { Instance },
    tag: string
): (boolean, string?)
    local targets = {} :: { Instance }
    for _, instance in instances do
        if not instance:HasTag(tag) then table.insert(targets, instance) end
    end
    if #targets == 0 then return true, nil end

    local beginSuccess, recording = pcall(
        ChangeHistoryService.TryBeginRecording,
        ChangeHistoryService,
        "SuperProperties.AddTag",
        `Add {tag}`
    )
    if not beginSuccess then
        return false, `Could not start an undo recording: {recording}`
    end
    if not recording then
        return false, "Could not start an undo recording."
    end

    local changed = {} :: { Instance }
    local writeError: string? = nil
    for _, instance in targets do
        local success, result = pcall(instance.AddTag, instance, tag)
        if not success then
            writeError = tostring(result)
            break
        end
        table.insert(changed, instance)
    end

    if writeError then
        for changedIdx = #changed, 1, -1 do
            local instance = changed[changedIdx]
            pcall(instance.RemoveTag, instance, tag)
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
