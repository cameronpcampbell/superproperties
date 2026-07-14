--!strict

local function CreateCategoryOrder(
    categoryNames: { string },
    overrides: { [string]: number }
): { [string]: number }
    local categoryOrder = {}

    for categoryIdx, categoryName in categoryNames do
        categoryOrder[categoryName] = categoryIdx
    end

    for categoryName, layoutOrder in overrides do
        categoryOrder[categoryName] = layoutOrder
    end

    return categoryOrder
end

return CreateCategoryOrder({
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
