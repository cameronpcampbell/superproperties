--!strict

local CollectionService = game:GetService("CollectionService")

local LongPoll = require(script.Parent.Parent.Parent.longPoll)
type LongPollOptions = LongPoll.Options

local PollOptions: LongPollOptions = {
    MinInterval = 0.1,
    MaxInterval = 1,
    BackoffFactor = 1.5
}

export type TagSet = { [string]: boolean }

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
): (() -> (), (TagSet) -> ())
    local previousTags = GetTagSet(instance)

    local disconnect = LongPoll(PollOptions, function(): boolean
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

    local function sync(tags: TagSet)
        -- A caller which already reconciled a local tag mutation can advance
        -- the poll snapshot and avoid reporting that same mutation again.
        previousTags = table.clone(tags)
    end

    return disconnect, sync
end

return TagChanged
