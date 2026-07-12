--!strict

local function Combine(
    array: { string },
    hashmap: { [string]: number }
): { [string]: number }
    local outputHashMap = {}

    for idx, value in array do
        outputHashMap[value] = idx
    end

    if hashmap then
        for key, value in hashmap do
            outputHashMap[key] = value
        end
    end

    return outputHashMap
end

return Combine({
    "Appearance",
    "Data",
    "Listening",
    "Material Overrides",
    "Fog",
    "Exposure",
    "Transform",
    "Pivot",
    "Camera",
    "Character",
    "Character Jump Settings",
    "Controls",
    "Mobile",
    "Behavior",
    "AirProperties",
    "Networking",
    "Collision",
    "Localization",
    "Scrolling",
    "Selection",
    "State",
    "Permissions",
    "Scripting",
    "ServerAuthority",
    "Streaming",
    "Part",
    "Forcefield",
    "Teams",
    "Assembly"
}, {
    Attributes = 999999,
    Tags = 999998,
})
