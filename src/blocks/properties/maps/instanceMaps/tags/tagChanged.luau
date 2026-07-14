--!strict

local CollectionService = game:GetService("CollectionService")

local LongPoll = require(script.Parent.Parent.Parent.longPoll)
type LongPollOptions = LongPoll.Options

local PollOptions: LongPollOptions = {
    MinInterval = 0.1,
    MaxInterval = 1,
    BackoffFactor = 1.5
}

type TagSet = { [string]: boolean }

local function GetTagSet(instance: Instance): TagSet
    local tags: TagSet = {}
    for _, tag in CollectionService:GetTags(instance) do
        tags[tag] = true
    end

    return tags
end

local function TagChanged(
    instance: Instance,
    callback: (tag: string, removed: boolean) -> ()
): () -> ()
    local previousTags = GetTagSet(instance)

    return LongPoll(PollOptions, function(): boolean
        local foundChanges = false
        local currentTags = GetTagSet(instance)
        for tag in currentTags do
            if previousTags[tag] then continue end

            foundChanges = true
            callback(tag, false)
        end

        for tag in pairs(previousTags) do
            if currentTags[tag] then continue end

            foundChanges = true
            callback(tag, true)
        end

        previousTags = currentTags
        return foundChanges
    end)
end

return TagChanged
