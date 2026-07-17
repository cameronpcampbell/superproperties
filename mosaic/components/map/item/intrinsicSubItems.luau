--!strict

local Types = require(script.Parent.Parent.types)

type Reader<T> = (rootValue: any) -> T

local function CreateVector3Items(
    readVector: Reader<Vector3>
): Types.IntrinsicItems
    return {
        {
            Key = "X",
            Value = {
                Read = function(rootValue: any)
                    return readVector(rootValue).X
                end
            }
        },
        {
            Key = "Y",
            Value = {
                Read = function(rootValue: any)
                    return readVector(rootValue).Y
                end
            }
        },
        {
            Key = "Z",
            Value = {
                Read = function(rootValue: any)
                    return readVector(rootValue).Z
                end
            }
        }
    }
end

local function CreateVector2Items(
    readVector: Reader<Vector2>
): Types.IntrinsicItems
    return {
        {
            Key = "X",
            Value = {
                Read = function(rootValue: any)
                    return readVector(rootValue).X
                end
            }
        },
        {
            Key = "Y",
            Value = {
                Read = function(rootValue: any)
                    return readVector(rootValue).Y
                end
            }
        }
    }
end

local function CreateUDimItems(
    readUDim: Reader<UDim>
): Types.IntrinsicItems
    return {
        {
            Key = "Scale",
            Value = {
                Read = function(rootValue: any)
                    return readUDim(rootValue).Scale
                end
            }
        },
        {
            Key = "Offset",
            Value = {
                Read = function(rootValue: any)
                    return readUDim(rootValue).Offset
                end
            }
        }
    }
end

local function CreateUDim2Items(
    readUDim2: Reader<UDim2>
): Types.IntrinsicItems
    local function readX(rootValue: any): UDim
        return readUDim2(rootValue).X
    end
    local function readY(rootValue: any): UDim
        return readUDim2(rootValue).Y
    end

    return {
        {
            Key = "X",
            Value = {
                Read = readX
            },
            SubItems = CreateUDimItems(readX)
        },
        {
            Key = "Y",
            Value = {
                Read = readY
            },
            SubItems = CreateUDimItems(readY)
        }
    }
end

local function CreateCFrameItems(
    readCFrame: Reader<CFrame>
): Types.IntrinsicItems
    local function readPosition(rootValue: any): Vector3
        return readCFrame(rootValue).Position
    end
    local function readOrientation(rootValue: any): Vector3
        local x, y, z = readCFrame(rootValue):ToOrientation()

        return Vector3.new(
            math.deg(x),
            math.deg(y),
            math.deg(z)
        )
    end

    return {
        {
            Key = "Position",
            Value = {
                Read = readPosition
            },
            SubItems = CreateVector3Items(readPosition)
        },
        {
            Key = "Orientation",
            Value = {
                Read = readOrientation
            },
            SubItems = CreateVector3Items(readOrientation)
        }
    }
end

local function CreateFontItems(
    readFont: Reader<Font>
): Types.IntrinsicItems
    return {
        {
            Key = "Style",
            Value = {
                Read = function(rootValue: any)
                    return readFont(rootValue).Style
                end
            }
        },
        {
            Key = "Weight",
            Value = {
                Read = function(rootValue: any)
                    return readFont(rootValue).Weight
                end
            }
        }
    }
end

local function ReadCFrame(rootValue: any): CFrame
    return rootValue :: CFrame
end

local function ReadVector3(rootValue: any): Vector3
    return rootValue :: Vector3
end

local function ReadVector2(rootValue: any): Vector2
    return rootValue :: Vector2
end

local function ReadUDim2(rootValue: any): UDim2
    return rootValue :: UDim2
end

local function ReadFont(rootValue: any): Font
    return rootValue :: Font
end

local IntrinsicSubItems: { [string]: Types.IntrinsicItems } = {
    CFrame = CreateCFrameItems(ReadCFrame),
    Vector3 = CreateVector3Items(ReadVector3),
    Vector2 = CreateVector2Items(ReadVector2),
    UDim2 = CreateUDim2Items(ReadUDim2),
    Font = CreateFontItems(ReadFont)
}

return IntrinsicSubItems
