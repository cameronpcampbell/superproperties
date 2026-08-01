--!strict

local Utils = script.Parent.Parent

local ColorSpace = require(Utils.colorSpace)

local function GetBestColor(
    surfaceColor: Color3,
    firstBaseColor: Color3,
    secondBaseColor: Color3
): Color3
    local surface = ColorSpace.Srgb.From(surfaceColor)
    local firstContrast = surface:CheckContrast(
        ColorSpace.Srgb.From(firstBaseColor)
    )
    local secondContrast = surface:CheckContrast(
        ColorSpace.Srgb.From(secondBaseColor)
    )

    return
        if firstContrast.ratio >= secondContrast.ratio then firstBaseColor
        else secondBaseColor
end

return GetBestColor
