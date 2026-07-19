--!strict

local ChangeHistoryService = game:GetService("ChangeHistoryService")

local function RenameTag(
    instance: Instance,
    oldTag: string,
    newTag: string
): boolean
    -- Keep the old tag intact if adding its replacement fails.
    instance:AddTag(newTag)
    instance:RemoveTag(oldTag)
    return true
end

return function(
    instance: Instance,
    oldTag: string,
    newTag: string
): (boolean, string?)
    local beginSuccess, recording = pcall(
        ChangeHistoryService.TryBeginRecording,
        ChangeHistoryService,
        "SuperProperties.SetTag",
        `Rename {oldTag} to {newTag}`
    )

    if not beginSuccess then
        return false, `Could not start an undo recording: {recording}`
    end

    if not recording then
        return false, "Could not start an undo recording."
    end

    local writeSuccess, writeResult = pcall(
        RenameTag,
        instance,
        oldTag,
        newTag
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
