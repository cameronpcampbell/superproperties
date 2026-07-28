--!strict

local Packages = script.Parent.Parent.Parent
local Fusion = require(Packages.fusion)

local FusionUtils = require(script.Parent.fusionUtils)
local ScopedData = FusionUtils.ScopedData

local DEFAULT_CURSOR = "rbxasset://SystemCursors/Arrow"

local PluginInstance = script:FindFirstAncestorOfClass("Plugin") :: Plugin?
local PluginMouse =
    if PluginInstance then PluginInstance:GetMouse() else nil

type Entry = {
    Owner: {},
    Image: string
}

export type Controller = {
    Set: (image: string) -> (),
    Clear: () -> ()
}

local function Apply(entries: { Entry })
    if not PluginMouse then return end

    local activeEntry = entries[#entries]
    PluginMouse.Icon =
        if activeEntry then activeEntry.Image
        else DEFAULT_CURSOR
end

return function(scope: Fusion.Scope): Controller
    local entries =
        ScopedData(scope, "CursorStack") :: { Entry }
    local owner = {}
    local activeImage: string? = nil

    local function RemoveOwner()
        for entryIdx = #entries, 1, -1 do
            if entries[entryIdx].Owner ~= owner then continue end

            table.remove(entries, entryIdx)
            return
        end
    end

    local function Set(image: string)
        if not PluginMouse then return end
        if activeImage == image then
            Apply(entries)
            return
        end

        if activeImage ~= nil then RemoveOwner() end
        activeImage = image
        table.insert(entries, {
            Owner = owner,
            Image = image
        })
        Apply(entries)
    end

    local function Clear()
        if activeImage == nil then return end

        activeImage = nil
        RemoveOwner()
        Apply(entries)
    end

    table.insert(scope, Clear)

    return {
        Set = Set,
        Clear = Clear
    }
end
