--!strict

local Packages = script.packages

local Fusion = require(Packages.fusion)
local Children = Fusion.Children

local Mosaic = require(Packages.mosaic)

local Blocks = script.blocks
local Properties = require(Blocks.properties)

local Assets = require(script.assets)

local Scope = Fusion.scoped(Fusion, Mosaic)

local Debug = script.debug.Value == "true"

Scope:Widget {
    Id = "Superproperties",
    Debug = Debug,

    [Children] = {
        Scope:Input {
            PlaceholderText = "Filter Properties",

            LeftChildren = Scope:IconButton {
                Image = Assets.Search,
            }
        },

        Scope:Scrollable {
            [Children] = {
                Properties(Scope, {

                }),

                Scope:New "UIListLayout" {
                    FillDirection = Enum.FillDirection.Vertical,
                    SortOrder = Enum.SortOrder.LayoutOrder,
                    Padding = UDim.new(0, 4)
                }
            }
        },

        Scope:New "UIPadding" {
            PaddingLeft = UDim.new(0, 4),
            PaddingRight = UDim.new(0, 4),
            PaddingTop = UDim.new(0, 4),
            PaddingBottom = UDim.new(0, 4),
        },

        Scope:New "UIListLayout" {
            FillDirection = Enum.FillDirection.Vertical,
            SortOrder = Enum.SortOrder.LayoutOrder,
            VerticalFlex = Enum.UIFlexAlignment.Fill,
            Padding = UDim.new(0, 4)
        }
    }
}
