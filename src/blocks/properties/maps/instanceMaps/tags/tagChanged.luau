--!strict

local CollectionService = game:GetService("CollectionService")

local LongPoll = require(script.Parent.Parent.Parent.longPoll)

local PollInterval = 0.1

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

    return LongPoll(PollInterval, function()
        local currentTags = GetTagSet(instance)
        for tag in currentTags do
            if previousTags[tag] then continue end
            callback(tag, false)
        end

        for tag in pairs(previousTags) do
            if currentTags[tag] then continue end
            callback(tag, true)
        end

        previousTags = currentTags
    end)
end

return TagChanged
