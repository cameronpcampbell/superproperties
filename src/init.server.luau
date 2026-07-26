--!strict

local ReflectionSecurity = require(script.reflectionSecurity)
ReflectionSecurity.Capture()

local Packages = script.packages

local Fusion = require(Packages.fusion)
local Children, OnEvent, Value, Peek =
    Fusion.Children, Fusion.OnEvent,
    Fusion.Value, Fusion.peek

local Mosaic = require(Packages.mosaic)
local SelectionService = Mosaic.SelectionService

local Blocks = script.blocks
local Properties = require(Blocks.properties)

local Scope = Fusion.scoped(Fusion, Mosaic)

local Debug = script.debug.Value:gsub("\n", "") == "true"

local function SyncTheme()
    Mosaic.SetTheme(Scope, Mosaic.DefaultThemeConfig())
end

SyncTheme()
settings().Studio.ThemeChanged:Connect(SyncTheme)

local function GetSelectedInstancesValue(
    scope: Fusion.Scope
): Fusion.Value<{ Instance }>
    local selectedInstancesValue =
        Value<<{ Instance }>>(scope, SelectionService:Get())
    local selectionUpdatePending = false

    local function QueueSelectionUpdate()
        if selectionUpdatePending then return end
        selectionUpdatePending = true

        task.defer(function()
            selectionUpdatePending = false
            selectedInstancesValue:set(SelectionService:Get())
        end)
    end

    table.insert(
        scope,
        SelectionService.SelectionChanged:Connect(QueueSelectionUpdate)
    )

    return selectedInstancesValue
end

local SelectedInstancesValue = GetSelectedInstancesValue(Scope)
local WidgetEnabled = Value(Scope, true)

local ComputeWidgetTitle = Scope:Computed(function(use, scope)
    local selectedInstances = use<<{ Instance }>>(SelectedInstancesValue)

    return
        if #selectedInstances == 1 then
            `SuperProperties - {selectedInstances[1].Name}`
        else if #selectedInstances > 1 then
            `SuperProperties - {#selectedInstances} items`
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
                Scope:New "Frame" {
                    Size = UDim2.fromScale(1, 0),
                    AutomaticSize = Enum.AutomaticSize.Y,
                    BackgroundTransparency = 1,

                    [Children] = {
                        Properties.Input(Scope),

                        Scope:New "UIPadding" {
                            PaddingLeft = UDim.new(0, 4),
                        },

                        Scope:New "UIFlexItem" {}
                    }
                },

                Properties.Maps(Scope, {
                    SelectedInstancesValue = SelectedInstancesValue,
                    OmitRbxAttributes = true
                }),

                Scope:New "UIPadding" {
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
