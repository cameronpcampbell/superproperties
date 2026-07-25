--!strict

local ChangeHistoryService = game:GetService("ChangeHistoryService")

return function(
    instance: Instance,
    tag: string
): (boolean, string?)
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

    local writeSuccess, writeResult = pcall(
        instance.AddTag,
        instance,
        tag
    )
    local operation =
        if writeSuccess then Enum.FinishRecordingOperation.Commit
        else Enum.FinishRecordingOperation.Cancel
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

    if not writeSuccess then
        return false, tostring(writeResult)
    end

    return true, nil
end
