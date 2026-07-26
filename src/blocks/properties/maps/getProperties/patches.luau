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

const HIDDEN_PATCH = table.freeze({
    CustomVisibility = false
}) :: PropertyPatch

local TextColorPatch = CreateDeprecationPatch("TextColor3")

local Patches: Patches = {
    Appearance = {
        Terrain = {
            SmoothVoxelsUpgraded = HIDDEN_PATCH
        },
        Lighting = {
            Technology = HIDDEN_PATCH
        },
        Decal = {
            TexturePack = HIDDEN_PATCH,
            TexturePackContent = HIDDEN_PATCH,
        }
    },
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
            RobloxLocked = HIDDEN_PATCH,
            SourceAssetId = HIDDEN_PATCH
        },
        Script = {
            Source = HIDDEN_PATCH
        },
        LocalScript = {
            Source = HIDDEN_PATCH
        },
        ModuleScript = {
            Source = HIDDEN_PATCH
        },
        GuiObject = {
            BackgroundColor = CreateDeprecationPatch("BackgroundColor3"),
            BorderColor = CreateDeprecationPatch("BorderColor3"),
            Transparency = CreateDeprecationPatch("BackgroundTransparency"),
            SelectionRect2D = HIDDEN_PATCH
        },
        Humanoid = {
            InternalDisplayName = HIDDEN_PATCH
        },
        WorldRoot = {
            PhysicsStepTime = HIDDEN_PATCH
        },
        Terrain = {
            LastUsedModificationMethod = HIDDEN_PATCH
        },
        ScrollingFrame = {
            DraggingScrollBar = HIDDEN_PATCH,
        },
        TextBox = {
            ManualFocusRelease = HIDDEN_PATCH,
            OverlayNativeInput = HIDDEN_PATCH,
            ReturnKeyType = HIDDEN_PATCH,
            ShouldEmitReturnEvents = HIDDEN_PATCH,
            ShouldEmitTabEvents = HIDDEN_PATCH,
            ShouldEmitUpAndDownArrowEvents = HIDDEN_PATCH,
            TextInputType = HIDDEN_PATCH,
        },
        TextChatService = {
            ChatTranslationFTUXShown = HIDDEN_PATCH,
            ChatTranslationToggleEnabled = HIDDEN_PATCH,
            EnableProtectedChat = HIDDEN_PATCH,
            HasSeenDeprecationDialog = HIDDEN_PATCH,
            IsLegacyChatDisabled = HIDDEN_PATCH,
        },
        Players = {
            MaxPlayersInternal = HIDDEN_PATCH,
            PreferredPlayersInternal = HIDDEN_PATCH,
        },
        StarterPlayer = {
            PlayerModuleStatus = HIDDEN_PATCH
        },
        StarterGui = {
            StudioDefaultStyleSheet = HIDDEN_PATCH,
            StudioInsertWidgetLayerCollectorAutoLinkStyleSheet = HIDDEN_PATCH,
        },
        SoundService = {
            AudioApiByDefault = HIDDEN_PATCH,
            IsNewExpForAudioApiByDefault = HIDDEN_PATCH,
        },
        ChatWindowConfiguration = {
            AbsolutePositionWrite = HIDDEN_PATCH,
            AbsoluteSizeWrite = HIDDEN_PATCH
        },
        ChatInputBarConfiguration = {
            AbsolutePositionWrite = HIDDEN_PATCH,
            AbsoluteSizeWrite = HIDDEN_PATCH,
            IsFocusedWrite = HIDDEN_PATCH
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
        },
        ["*"] = {
            LocalizationMatchIdentifier = HIDDEN_PATCH,
            LocalizationMatchedSourceText = HIDDEN_PATCH,
        }
    },
    Transform = {
        BasePart = {
            ExtentsSize = CreateDeprecationPatch("Size"),
            Orientation = HIDDEN_PATCH,
            ExtentsCFrame = HIDDEN_PATCH,
            Position = HIDDEN_PATCH
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
    },
    Scrolling = {
        ScrollingFrame = {
            ScrollRate = HIDDEN_PATCH,
            ScrollVelocity = HIDDEN_PATCH,
            SmoothScroll = HIDDEN_PATCH
        }
    },
    Debugging = {
        GuiBase2d = {
            ClippedRect = HIDDEN_PATCH,
            IsNotOccluded = HIDDEN_PATCH,
            RawRect2D = HIDDEN_PATCH,
            TotalGroupScale = HIDDEN_PATCH,
        },
        ScrollingFrame = {
            HorizontalBarRect = HIDDEN_PATCH,
            MaxCanvasPosition = HIDDEN_PATCH,
            VerticalBarRect = HIDDEN_PATCH
        }
    },
    Image = {
        ["*"] = {
            ContentImageSize = HIDDEN_PATCH
        }
    },
    Character = {
        StarterPlayer = {
            GameSettingsAssetIDFace = HIDDEN_PATCH,
            GameSettingsAssetIDHead = HIDDEN_PATCH,
            GameSettingsAssetIDLeftArm = HIDDEN_PATCH,
            GameSettingsAssetIDLeftLeg = HIDDEN_PATCH,
            GameSettingsAssetIDPants = HIDDEN_PATCH,
            GameSettingsAssetIDRightArm = HIDDEN_PATCH,
            GameSettingsAssetIDRightLeg = HIDDEN_PATCH,
            GameSettingsAssetIDShirt = HIDDEN_PATCH,
            GameSettingsAssetIDTeeShirt = HIDDEN_PATCH,
            GameSettingsAssetIDTorso = HIDDEN_PATCH,
            GameSettingsAvatar = HIDDEN_PATCH,
            GameSettingsR15Collision = HIDDEN_PATCH,
            GameSettingsScaleRangeBodyType = HIDDEN_PATCH,
            GameSettingsScaleRangeHead = HIDDEN_PATCH,
            GameSettingsScaleRangeHeight = HIDDEN_PATCH,
            GameSettingsScaleRangeProportion = HIDDEN_PATCH,
            GameSettingsScaleRangeWidth = HIDDEN_PATCH,
        }
    }
}

return Patches
