--!strict

local ChangeHistoryService = game:GetService("ChangeHistoryService")

return function(
    instance: Instance,
    oldAttributeName: string,
    newAttributeName: string
): (boolean, string?)
    if oldAttributeName == newAttributeName then
        return true, nil
    end

    local attributes = instance:GetAttributes()
    local attributeValue = attributes[oldAttributeName]

    if attributeValue == nil then
        return false, `Attribute {oldAttributeName} no longer exists.`
    end

    if attributes[newAttributeName] ~= nil then
        return false, `Attribute {newAttributeName} already exists.`
    end

    local beginSuccess, recording = pcall(
        ChangeHistoryService.TryBeginRecording,
        ChangeHistoryService,
        "SuperProperties.RenameAttribute",
        `Rename {oldAttributeName} to {newAttributeName}`
    )

    if not beginSuccess then
        return false, `Could not start an undo recording: {recording}`
    end

    if not recording then
        return false, "Could not start an undo recording."
    end

    local createSuccess, createResult = pcall(
        instance.SetAttribute,
        instance,
        newAttributeName,
        attributeValue
    )
    local removeSuccess = false
    local removeResult: any = nil

    if createSuccess then
        removeSuccess, removeResult = pcall(
            instance.SetAttribute,
            instance,
            oldAttributeName,
            nil
        )
    end

    local rollbackSuccess = true
    local rollbackResult: any = nil

    if createSuccess and not removeSuccess then
        rollbackSuccess, rollbackResult = pcall(
            instance.SetAttribute,
            instance,
            newAttributeName,
            nil
        )
    end

    local writeSuccess = createSuccess and removeSuccess
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

    if not createSuccess then
        return false, tostring(createResult)
    end

    if not removeSuccess then
        if not rollbackSuccess then
            return false,
                `Could not remove attribute {oldAttributeName}: {removeResult}; could not remove the newly created attribute {newAttributeName}: {rollbackResult}`
        end

        return false,
            `Could not remove attribute {oldAttributeName}: {removeResult}`
    end

    return true, nil
end
