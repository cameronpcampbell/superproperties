--!strict

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local PollInterval = 0.1

local function TagChanged(
    instance: Instance,
    callback: (tag: string, removed: boolean) -> ()
): RBXScriptConnection
    local previousTags: { [string]: boolean } = {}
    for _, tag in CollectionService:GetTags(instance) do
        previousTags[tag] = true
    end

    local elapsed = 0

    return RunService.Heartbeat:Connect(function(deltaTime: number)
        elapsed += deltaTime
        if elapsed < PollInterval then return end
        elapsed = 0

        local currentTags: { [string]: boolean } = {}
        for _, tag in CollectionService:GetTags(instance) do
            currentTags[tag] = true

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
