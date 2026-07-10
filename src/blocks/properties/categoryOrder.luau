--!strict

local function IntoHashSet(tble: { string }): { [string]: number }
    local hashSet = {}

    for idx, value in tble do
        hashSet[value] = idx
    end

    return hashSet
end

return IntoHashSet({
    "Appearance",
    "Data",
    "Listening",
    "Material Overrides",
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
    "Assembly",
    "Tags",
    "Attributes"
})
