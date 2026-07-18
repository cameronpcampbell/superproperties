--!strict

local CreateTextVariant = require(script.Parent.utils.createTextVariant)
local NormalizeNumber = require(script.Parent.utils.normalizeNumber)
local ParseCFrame = require(script.parser)

local function FormatComponent(value: number): string
    return tostring(NormalizeNumber(value))
end

local function FormatVector(value: Vector3): string
    local x = FormatComponent(value.X)
    local y = FormatComponent(value.Y)
    local z = FormatComponent(value.Z)

    return `{x}, {y}, {z}`
end

local function FormatValue(value: CFrame): string
    local position = FormatVector(value.Position)
    local x, y, z = value:ToOrientation()
    local orientation = Vector3.new(
        NormalizeNumber(math.deg(x)),
        NormalizeNumber(math.deg(y)),
        NormalizeNumber(math.deg(z))
    )

    return string.format("{%s}, {%s}", position, FormatVector(orientation))
end

local function ParseValue(text: string): (CFrame?, string?)
    local components, parseError = ParseCFrame(text)
    if components == nil then
        return nil, parseError
    end

    local position = components.Position
    local value = CFrame.new(position.X, position.Y, position.Z)
    local orientation = components.Orientation

    if orientation ~= nil then
        value *= CFrame.fromOrientation(
            math.rad(orientation.X),
            math.rad(orientation.Y),
            math.rad(orientation.Z)
        )
    end

    return value, nil
end

return CreateTextVariant<<CFrame>>({
    InputName = "CFrameValueInput",
    Format = FormatValue,
    Parse = ParseValue
})
