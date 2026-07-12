--!strict

local SelectionService = game:GetService("Selection")

local Packages = script.packages

local Fusion = require(Packages.fusion)
local Value, Children = Fusion.Value, Fusion.Children

local Mosaic = require(Packages.mosaic)

local Blocks = script.blocks
local Properties = require(Blocks.properties)

local Assets = require(script.assets)

local Scope = Fusion.scoped(Fusion, Mosaic)

local Debug = script.debug.Value:gsub("\n", "") == "true"

local function GetSelectedInstanceValue(scope: Fusion.Scope)
    local selectedInstanceValue = Value(scope, SelectionService:Get()[1])

    SelectionService.SelectionChanged:Connect(function()
        selectedInstanceValue:set(SelectionService:Get()[1])
    end)

    return selectedInstanceValue
end

local SelectedInstanceValue = GetSelectedInstanceValue(Scope)

local ComputeWidgetTitle = Scope:Computed(function(use, scope)
    local usedSelectedInstance = use<<Instance>>(SelectedInstanceValue)

    return
        if usedSelectedInstance then
            `SuperProperties - {usedSelectedInstance.Name}`
        else `SuperProperties`
end)

Scope:Widget {
    Id = "Superproperties",
    Title = ComputeWidgetTitle,
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
                Properties(Scope, SelectedInstanceValue),

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
