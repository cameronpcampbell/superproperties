--!strict
--!nolint LocalShadow

local Packages = script.Parent.Parent.Parent.Parent.Parent.packages
local Typeforge = require(Packages.typeforge)


local Types = require(script.Parent.types)

type Patches = {
    -- Category
    [string]: {
        -- Owner
        [string]: {
            -- Property Name
            [string]: {
                [string]: Typeforge.Partial<Types.PatchedReflectionPropertiesItem>
            }
        }
    }
}

local Patches: Patches = {
    Behavior = {
        ["*"] = {

            Archivable = {
                Display = {
                    Category = "Data"
                }
            }

        },
        BaseScript = {

            Disabled = {
                Display = {
                    DeprecationMessage = "Use 'Enabled' instead."
                }
            }

        },
    },
    Data = {
        GuiObject = {

            BackgroundColor = {
                Display = {
                    DeprecationMessage = "Use 'BackgroundColor3' instead."
                }
            },

            BorderColor = {
                Display = {
                    DeprecationMessage = "Use 'BorderColor3' instead."
                }
            },

            Transparency = {
                Display = {
                    DeprecationMessage = "Use 'BackgroundTransparency' instead."
                }
            }

        }
    },
    Text = {
        TextLabel = {

            TextColor = {
                Display = {
                    DeprecationMessage = "Use 'TextColor3' instead."
                }
            }

        },
        TextButton = {

            TextColor = {
                Display = {
                    DeprecationMessage = "Use 'TextColor3' instead."
                }
            }

        },
        TextBox = {

            TextColor = {
                Display = {
                    DeprecationMessage = "Use 'TextColor3' instead."
                }
            }

        }
    },
    Transform = {
        PVInstance = {

            Origin = {
                CustomReadWrite = {
                    Read = function(inst: PVInstance)
                        return inst:GetPivot()
                    end,

                    Write = function(inst: PVInstance, write: CFrame)
                        inst:PivotTo(write)
                    end
                }
            }

        }
    }
}

return Patches
