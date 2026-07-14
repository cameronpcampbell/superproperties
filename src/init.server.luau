--!strict

local SelectionService = game:GetService("Selection")

local Packages = script.packages

local Fusion = require(Packages.fusion)
local Children, Value = Fusion.Children, Fusion.Value

local Mosaic = require(Packages.mosaic)

local Blocks = script.blocks
local Properties = require(Blocks.properties)

local Scope = Fusion.scoped(Fusion, Mosaic)

local Debug = script.debug.Value:gsub("\n", "") == "true"

local function GetSelectedInstanceValue(
    scope: Fusion.Scope
): Fusion.Value<Instance?>
    local selectedInstanceValue =
        Value<<Instance?>>(scope, SelectionService:Get()[1])

    SelectionService.SelectionChanged:Connect(function()
        selectedInstanceValue:set(SelectionService:Get()[1])
    end)

    return selectedInstanceValue
end

local SelectedInstanceValue = GetSelectedInstanceValue(Scope)

local ComputeWidgetTitle = Scope:Computed(function(use, scope)
    local usedSelectedInstance = use<<Instance?>>(SelectedInstanceValue)

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
        Scope:New "Frame" {
            Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1,
            Name = "Content",

            [Children] = {
                Properties.Input(Scope),

                Properties.Maps(Scope, {
                    SelectedInstanceValue = SelectedInstanceValue,
                    OmitRbxAttributes = true
                }),

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
    }
}
