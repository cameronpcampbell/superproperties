--!strict

local Types = require(script.Parent.Parent.types)

local IntrinsicSubItems: { [string]: Types.IntrinsicItems } = {
    CFrame = {
        {
            Key = "Position",
            Value = {
                Read = function(value: CFrame)
                    return value.Position
                end
            }
        },
        {
            Key = "Orientation",
            Value = {
                Read = function(value: CFrame)
                    local x, y, z = value:ToOrientation()

                    return Vector3.new(
                        math.deg(x),
                        math.deg(y),
                        math.deg(z)
                    )
                end
            }
        }
    },
    Vector3 = {
        {
            Key = "X",
            Value = {
                Read = function(value: Vector3)
                    return value.X
                end
            }
        },
        {
            Key = "Y",
            Value = {
                Read = function(value: Vector3)
                    return value.Y
                end
            }
        },
        {
            Key = "Z",
            Value = {
                Read = function(value: Vector3)
                    return value.Z
                end
            }
        }
    },
    Vector2 = {
        {
            Key = "X",
            Value = {
                Read = function(value: Vector2)
                    return value.X
                end
            }
        },
        {
            Key = "Y",
            Value = {
                Read = function(value: Vector2)
                    return value.Y
                end
            }
        }
    },
    UDim2 = {
        {
            Key = "X",
            Value = {
                Read = function(value: UDim2)
                    return value.X
                end
            },
            SubItems = {
                {
                    Key = "Scale",
                    Value = {
                        Read = function(value: UDim)
                            return value.Scale
                        end
                    }
                },
                {
                    Key = "Offset",
                    Value = {
                        Read = function(value: UDim)
                            return value.Offset
                        end
                    }
                }
            }
        },
        {
            Key = "Y",
            Value = {
                Read = function(value: UDim2)
                    return value.Y
                end
            },
            SubItems = {
                {
                    Key = "Scale",
                    Value = {
                        Read = function(value: UDim)
                            return value.Scale
                        end
                    }
                },
                {
                    Key = "Offset",
                    Value = {
                        Read = function(value: UDim)
                            return value.Offset
                        end
                    }
                }
            }
        }
    }
}

return IntrinsicSubItems
