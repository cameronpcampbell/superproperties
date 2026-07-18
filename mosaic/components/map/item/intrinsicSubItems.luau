--!strict

local Types = require(script.Parent.Parent.types)

type Reader<T> = (rootValue: any) -> T
type Writer<T> = (rootValue: any, value: T) -> any

local function CreateVector3Items(
    readVector: Reader<Vector3>,
    writeVector: Writer<Vector3>
): Types.IntrinsicItems
    return {
        {
            Key = "X",
            Value = {
                Read = function(rootValue: any)
                    return readVector(rootValue).X
                end,
                Write = function(rootValue: any, value: number)
                    local vector = readVector(rootValue)

                    return writeVector(
                        rootValue,
                        Vector3.new(value, vector.Y, vector.Z)
                    )
                end
            }
        },
        {
            Key = "Y",
            Value = {
                Read = function(rootValue: any)
                    return readVector(rootValue).Y
                end,
                Write = function(rootValue: any, value: number)
                    local vector = readVector(rootValue)

                    return writeVector(
                        rootValue,
                        Vector3.new(vector.X, value, vector.Z)
                    )
                end
            }
        },
        {
            Key = "Z",
            Value = {
                Read = function(rootValue: any)
                    return readVector(rootValue).Z
                end,
                Write = function(rootValue: any, value: number)
                    local vector = readVector(rootValue)

                    return writeVector(
                        rootValue,
                        Vector3.new(vector.X, vector.Y, value)
                    )
                end
            }
        }
    }
end

local function CreateVector2Items(
    readVector: Reader<Vector2>,
    writeVector: Writer<Vector2>
): Types.IntrinsicItems
    return {
        {
            Key = "X",
            Value = {
                Read = function(rootValue: any)
                    return readVector(rootValue).X
                end,
                Write = function(rootValue: any, value: number)
                    local vector = readVector(rootValue)

                    return writeVector(
                        rootValue,
                        Vector2.new(value, vector.Y)
                    )
                end
            }
        },
        {
            Key = "Y",
            Value = {
                Read = function(rootValue: any)
                    return readVector(rootValue).Y
                end,
                Write = function(rootValue: any, value: number)
                    local vector = readVector(rootValue)

                    return writeVector(
                        rootValue,
                        Vector2.new(vector.X, value)
                    )
                end
            }
        }
    }
end

local function CreateUDimItems(
    readUDim: Reader<UDim>,
    writeUDim: Writer<UDim>
): Types.IntrinsicItems
    return {
        {
            Key = "Scale",
            Value = {
                Read = function(rootValue: any)
                    return readUDim(rootValue).Scale
                end,
                Write = function(rootValue: any, value: number)
                    local uDim = readUDim(rootValue)

                    return writeUDim(
                        rootValue,
                        UDim.new(value, uDim.Offset)
                    )
                end
            }
        },
        {
            Key = "Offset",
            Value = {
                Read = function(rootValue: any)
                    return readUDim(rootValue).Offset
                end,
                Write = function(rootValue: any, value: number)
                    local uDim = readUDim(rootValue)

                    return writeUDim(
                        rootValue,
                        UDim.new(uDim.Scale, value)
                    )
                end
            }
        }
    }
end

local function CreateUDim2Items(
    readUDim2: Reader<UDim2>,
    writeUDim2: Writer<UDim2>
): Types.IntrinsicItems
    local function readX(rootValue: any): UDim
        return readUDim2(rootValue).X
    end
    local function readY(rootValue: any): UDim
        return readUDim2(rootValue).Y
    end
    local function writeX(rootValue: any, value: UDim): any
        local uDim2 = readUDim2(rootValue)

        return writeUDim2(rootValue, UDim2.new(value, uDim2.Y))
    end
    local function writeY(rootValue: any, value: UDim): any
        local uDim2 = readUDim2(rootValue)

        return writeUDim2(rootValue, UDim2.new(uDim2.X, value))
    end

    return {
        {
            Key = "X",
            Value = {
                Read = readX,
                Write = writeX
            },
            SubItems = CreateUDimItems(readX, writeX)
        },
        {
            Key = "Y",
            Value = {
                Read = readY,
                Write = writeY
            },
            SubItems = CreateUDimItems(readY, writeY)
        }
    }
end

local function CreateCFrameItems(
    readCFrame: Reader<CFrame>,
    writeCFrame: Writer<CFrame>
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
    local function writePosition(rootValue: any, value: Vector3): any
        local cFrame = readCFrame(rootValue)

        return writeCFrame(
            rootValue,
            CFrame.new(value) * cFrame.Rotation
        )
    end
    local function writeOrientation(rootValue: any, value: Vector3): any
        local cFrame = readCFrame(rootValue)

        return writeCFrame(
            rootValue,
            CFrame.new(cFrame.Position) * CFrame.fromOrientation(
                math.rad(value.X),
                math.rad(value.Y),
                math.rad(value.Z)
            )
        )
    end

    return {
        {
            Key = "Position",
            Value = {
                Read = readPosition,
                Write = writePosition
            },
            SubItems = CreateVector3Items(readPosition, writePosition)
        },
        {
            Key = "Orientation",
            Value = {
                Read = readOrientation,
                Write = writeOrientation
            },
            SubItems = CreateVector3Items(readOrientation, writeOrientation)
        }
    }
end

local function CreateFacesItems(
    readFaces: Reader<Faces>,
    writeFaces: Writer<Faces>
): Types.IntrinsicItems
    local function writeFace(
        rootValue: any,
        targetFace: Enum.NormalId,
        value: boolean
    ): any
        local faces = readFaces(rootValue)
        local normalIds = {} :: { Enum.NormalId }

        local function addFace(
            normalId: Enum.NormalId,
            isEnabled: boolean
        )
            if normalId == targetFace then isEnabled = value end
            if isEnabled then table.insert(normalIds, normalId) end
        end

        addFace(Enum.NormalId.Back, faces.Back)
        addFace(Enum.NormalId.Bottom, faces.Bottom)
        addFace(Enum.NormalId.Front, faces.Front)
        addFace(Enum.NormalId.Left, faces.Left)
        addFace(Enum.NormalId.Right, faces.Right)
        addFace(Enum.NormalId.Top, faces.Top)

        return writeFaces(rootValue, Faces.new(table.unpack(normalIds)))
    end

    local function createFaceItem(
        key: string,
        normalId: Enum.NormalId,
        readFace: (faces: Faces) -> boolean
    ): Types.IntrinsicItem
        return {
            Key = key,
            Value = {
                Read = function(rootValue: any): boolean
                    return readFace(readFaces(rootValue))
                end,
                Write = function(rootValue: any, value: boolean): any
                    return writeFace(rootValue, normalId, value)
                end
            }
        }
    end

    return {
        createFaceItem(
            "Back",
            Enum.NormalId.Back,
            function(faces: Faces): boolean return faces.Back end
        ),
        createFaceItem(
            "Bottom",
            Enum.NormalId.Bottom,
            function(faces: Faces): boolean return faces.Bottom end
        ),
        createFaceItem(
            "Front",
            Enum.NormalId.Front,
            function(faces: Faces): boolean return faces.Front end
        ),
        createFaceItem(
            "Left",
            Enum.NormalId.Left,
            function(faces: Faces): boolean return faces.Left end
        ),
        createFaceItem(
            "Right",
            Enum.NormalId.Right,
            function(faces: Faces): boolean return faces.Right end
        ),
        createFaceItem(
            "Top",
            Enum.NormalId.Top,
            function(faces: Faces): boolean return faces.Top end
        )
    }
end

local function CreateFontItems(
    readFont: Reader<Font>,
    writeFont: Writer<Font>
): Types.IntrinsicItems
    return {
        {
            Key = "Style",
            Value = {
                Read = function(rootValue: any)
                    return readFont(rootValue).Style
                end,
                Write = function(rootValue: any, value: Enum.FontStyle)
                    local font = readFont(rootValue)

                    return writeFont(
                        rootValue,
                        Font.new(font.Family, font.Weight, value :: Enum.FontStyle)
                    )
                end
            }
        },
        {
            Key = "Weight",
            Value = {
                Read = function(rootValue: any)
                    return readFont(rootValue).Weight
                end,
                Write = function(rootValue: any, value: Enum.FontWeight)
                    local font = readFont(rootValue)

                    return writeFont(
                        rootValue,
                        Font.new(font.Family, value :: Enum.FontWeight, font.Style)
                    )
                end
            }
        }
    }
end

local function ReadRoot<T>(rootValue: any): T
    return rootValue :: T
end

local function WriteRoot<T>(_rootValue: any, value: T): T
    return value
end

local IntrinsicSubItems: { [string]: Types.IntrinsicItems } = {
    CFrame = CreateCFrameItems(ReadRoot, WriteRoot),
    Vector3 = CreateVector3Items(ReadRoot, WriteRoot),
    Vector2 = CreateVector2Items(ReadRoot, WriteRoot),
    UDim2 = CreateUDim2Items(ReadRoot, WriteRoot),
    Faces = CreateFacesItems(ReadRoot, WriteRoot),
    Font = CreateFontItems(ReadRoot, WriteRoot)
}

return IntrinsicSubItems
