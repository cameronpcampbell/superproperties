--!strict
--!nolint LocalShadow

local Packages = script.Parent.Parent.Parent.Parent.Parent.packages
local Typeforge = require(Packages.typeforge)

local Types = require(script.Parent.types)

type DisplayPatch = {
    Category: string?,
    DeprecationMessage: string?,
    LayoutOrder: number?
}

type PropertyPatch = Typeforge.Flatten<
    Typeforge.Omit<
        Typeforge.Partial<Types.PatchedReflectionPropertiesItem>,
        "Display"
    > & {
        Display: DisplayPatch?
    }
>

type Patches = {
    [string]: {
        [string]: {
            [string]: PropertyPatch
        }
    }
}

local function CreateDeprecationPatch(replacement: string): PropertyPatch
    return {
        Display = {
            DeprecationMessage = `Use '{replacement}' instead.`
        }
    }
end

local function CreateHiddenPatch(): PropertyPatch
    return {
        Display = {
            DeprecationMessage = "Hidden from the properties explorer."
        }
    }
end

local TextColorPatch = CreateDeprecationPatch("TextColor3")

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
            Disabled = CreateDeprecationPatch("Enabled")
        },
    },
    Data = {
        Instance = {
            RobloxLocked = CreateHiddenPatch()
        },
        Script = {
            Source = CreateHiddenPatch()
        },
        LocalScript = {
            Source = CreateHiddenPatch()
        },
        ModuleScript = {
            Source = CreateHiddenPatch()
        },
        GuiObject = {
            BackgroundColor = CreateDeprecationPatch("BackgroundColor3"),
            BorderColor = CreateDeprecationPatch("BorderColor3"),
            Transparency = CreateDeprecationPatch("BackgroundTransparency")
        }
    },
    Text = {
        TextLabel = {
            TextColor = TextColorPatch
        },
        TextButton = {
            TextColor = TextColorPatch
        },
        TextBox = {
            TextColor = TextColorPatch
        }
    },
    Transform = {
        BasePart = {
            ExtentsSize = CreateDeprecationPatch("Size"),
            Orientation = CreateHiddenPatch(),
            ExtentsCFrame = CreateHiddenPatch(),
            Position = CreateHiddenPatch()
        },
        PVInstance = {
            Origin = {
                CustomReadWrite = {
                    Read = function(instance: PVInstance)
                        return instance:GetPivot()
                    end,

                    Write = function(instance: PVInstance, value: CFrame)
                        instance:PivotTo(value)
                    end,

                    -- This can change through descendants without a reliable
                    -- property signal on the selected instance.
                    Poll = true
                }
            }
        }
    },
    Part = {
        BasePart = {
            size = CreateDeprecationPatch("Size")
        }
    },
    Pivot = {
        Model = {
            Scale = {
                CustomReadWrite = {
                    Read = function(instance: Model)
                        return instance:GetScale()
                    end,

                    Write = function(instance: Model, value: number)
                        instance:ScaleTo(value)
                    end,

                    Poll = true
                }
            }
        }
    },
    Permissions = {
        ["*"] = {
            Capabilities = {
                Display = {
                    DeprecationMessage = "Deprecated in the properties explorer."
                }
            }
        }
    }
}

return Patches
