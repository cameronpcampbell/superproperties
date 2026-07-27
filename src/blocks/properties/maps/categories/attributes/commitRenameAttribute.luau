--!strict

local ChangeHistoryService = game:GetService("ChangeHistoryService")

type Target = {
    Instance: Instance,
    Value: any
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
    oldAttributeName: string,
    newAttributeName: string
): (boolean, string?)
    if oldAttributeName == newAttributeName then return true, nil end

    local targets = table.create(#instances) :: { Target }
    for targetIdx, instance in instances do
        local attributes = instance:GetAttributes()
        local attributeValue = attributes[oldAttributeName]

        if attributeValue == nil then
            return false, `Attribute {oldAttributeName} no longer exists.`
        end
        if attributes[newAttributeName] ~= nil then
            return false, `Attribute {newAttributeName} already exists.`
        end

        targets[targetIdx] = {
            Instance = instance,
            Value = attributeValue
        }
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

    local changed = {} :: { Target }
    local writeError: string? = nil

    for _, target in targets do
        local createSuccess, createResult = SetAttribute(
            target.Instance,
            newAttributeName,
            target.Value
        )
        if not createSuccess then
            writeError = tostring(createResult)
            break
        end

        table.insert(changed, target)
        local removeSuccess, removeResult = SetAttribute(
            target.Instance,
            oldAttributeName,
            nil
        )
        if not removeSuccess then
            writeError = tostring(removeResult)
            break
        end
    end

    if writeError then
        for changedIdx = #changed, 1, -1 do
            local target = changed[changedIdx]
            SetAttribute(target.Instance, oldAttributeName, target.Value)
            SetAttribute(target.Instance, newAttributeName, nil)
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
