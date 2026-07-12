--!strict
--!nolint LocalShadow

type Patches = {
    -- Category
    [string]: {
        -- Owner
        [string]: {
            -- Property Name
            [string]: {
                [string]: any
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
    }
}

return Patches
