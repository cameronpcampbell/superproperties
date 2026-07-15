--!strict

local Types = require(script.Parent.Parent.types)

local IntrinsicSubItems: { [string]: Types.Items } = {
    --[[CFrame = {
        {
            Key = "Position",
            Value = "0, 0, 0",
            SubItems = {
                {
                    Key = "X",
                    Value = "0"
                },
                {
                    Key = "Y",
                    Value = "0"
                },
                {
                    Key = "Z",
                    Value = "0"
                }
            }
        },
        {
            Key = "Orientation",
            Value = "0, 0, 0",
            SubItems = {
                {
                    Key = "X",
                    Value = "0"
                },
                {
                    Key = "Y",
                    Value = "0"
                },
                {
                    Key = "Z",
                    Value = "0"
                }
            }
        }
    },
    Vector3 = {
        {
            Key = "X",
            Value = "0"
        },
        {
            Key = "Y",
            Value = "0"
        },
        {
            Key = "Z",
            Value = "0"
        }
    },]]
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
    --[[UDim2 = {
        {
            Key = "X",
            Value = "{0, 0}",
            SubItems = {
                {
                    Key = "Scale",
                    Value = "0"
                },
                {
                    Key = "Offset",
                    Value = "0"
                }
            }
        },
        {
            Key = "Y",
            Value = "{0, 0}",
            SubItems = {
                {
                    Key = "Scale",
                    Value = "0"
                },
                {
                    Key = "Offset",
                    Value = "0"
                }
            }
        }
    }]]
}

return IntrinsicSubItems
