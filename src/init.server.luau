--!strict

local SelectionService = game:GetService("Selection")

local Packages = script.packages

local Fusion = require(Packages.fusion)
local Children, OnEvent, Value, Peek =
    Fusion.Children, Fusion.OnEvent,
    Fusion.Value, Fusion.peek

local Mosaic = require(Packages.mosaic)

local Blocks = script.blocks
local Properties = require(Blocks.properties)

local Scope = Fusion.scoped(Fusion, Mosaic)

local function SyncTheme()
    Mosaic.SetTheme(Scope, Mosaic.DefaultThemeConfig())
end

SyncTheme()

local Debug = script.debug.Value:gsub("\n", "") == "true"

--[[local theme = Scope:DefaultThemeConfig()
for key, value in (theme :: { [string]: any }) do
    if typeof(value) ~= "Color3" then continue end

    (theme :: any)[key] = require(Packages.mosaic.utils.colorSpace).Stringify.Hex(value)
end
print(theme)]]

settings().Studio.ThemeChanged:Connect(SyncTheme)

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
local WidgetEnabled = Value(Scope, true)

local ComputeWidgetTitle = Scope:Computed(function(use, scope)
    local usedSelectedInstance = use<<Instance?>>(SelectedInstanceValue)

    return
        if usedSelectedInstance then
            `SuperProperties - {usedSelectedInstance.Name}`
        else `SuperProperties`
end)

local Widget = Scope:Widget {
    Id = "Superproperties",
    Title = ComputeWidgetTitle,
    Debug = Debug,
    Enabled = WidgetEnabled,

    [Children] = {
        Scope:New "Frame" {
            Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1,
            Name = "Content",

            [Children] = {
                --[[Properties.Input(Scope),

                Properties.Maps(Scope, {
                    SelectedInstanceValue = SelectedInstanceValue,
                    OmitRbxAttributes = true
                }),]]

                Scope:SelectMenu {
                    Items = {
                        "Hello",
                        "World",
                        "Foo",
                        "Bar",
                        "Baz",
                        "Lol",
                        "Hi",
                        "Bye",
                        "Apple",
                        "Pear",
                        "Kiwi"
                    },
                    MaxHeight = 150
                },

                Scope:New "UIPadding" {
                    PaddingLeft = UDim.new(0, 4),
                    PaddingRight = UDim.new(0, 4),
                    PaddingTop = UDim.new(0, 4),
                    -- For some reason plugin gui's are
                    -- clipped 1 pixel at the bottom.
                    PaddingBottom = UDim.new(0, 5),
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
} :: DockWidgetPluginGui

Scope:Toolbar {
    Name = "SuperProperties",

    [Children] = Scope:ToolbarButton {
        Id = "SuperProperties",
        Tooltip = "Toggle the SuperProperties widget",
        Text = "SuperProperties",
        Active = WidgetEnabled,
        ClickableWhenViewportHidden = true,

        [OnEvent "Click"] = function()
            WidgetEnabled:set(not Peek<<boolean>>(WidgetEnabled))
        end
    }
}

table.insert(Scope, Widget:GetPropertyChangedSignal("Enabled"):Connect(function()
    WidgetEnabled:set(Widget.Enabled)
end))
