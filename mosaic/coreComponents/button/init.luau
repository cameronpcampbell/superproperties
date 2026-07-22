--!strict

local Packages = script.Parent.Parent.Parent
local Fusion = require(Packages.fusion)
local OnEvent = Fusion.OnEvent

local Utils = script.Parent.Parent.utils

local FusionUtils = require(Utils.fusionUtils)
local ConstructorComponent, CombineProps =
    FusionUtils.ConstructorComponent, FusionUtils.CombineProps

local Root = require(Utils.root)

local DEFAULT_CURSOR = "rbxasset://SystemCursors/Arrow"
local POINTER_CURSOR = "rbxasset://SystemCursors/PointingHand"

local MOUSE_LEAVE_EVENT = OnEvent "MouseLeave"

local PluginInstance = script:FindFirstAncestorOfClass("Plugin") :: Plugin?
local PluginMouse =
    if PluginInstance then PluginInstance:GetMouse() else nil

type ButtonProps = {
    [any]: any,
}

return ConstructorComponent<<ButtonProps>>(function(scope, constructor, props)
    local onMouseLeaveEvent =
        (props :: { [any]: any })[MOUSE_LEAVE_EVENT] :: () -> ()
    local isHovering = false

    local function ShowPointer()
        local pluginMouse = PluginMouse
        if not pluginMouse then return end

        isHovering = true
        pluginMouse.Icon = POINTER_CURSOR
    end

    local function RestorePointer()
        local pluginMouse = PluginMouse
        if not pluginMouse or not isHovering then return end

        isHovering = false

        if pluginMouse.Icon == POINTER_CURSOR then
            pluginMouse.Icon = DEFAULT_CURSOR
        end
    end

    local destroyRootMouseLeave = Root.AddEvent(
        scope,
        "MouseLeave",
        function()
            RestorePointer()
            onMouseLeaveEvent()
        end
    )

    local function CleanupButton()
        RestorePointer()
        destroyRootMouseLeave()
    end

    table.insert(scope, RestorePointer)

    local button = constructor(scope, CombineProps(props, {
        [OnEvent "Destroying"] = CleanupButton,
    })) :: GuiButton

    table.insert(scope, button.MouseEnter:Connect(ShowPointer))
    table.insert(scope, button.MouseMoved:Connect(ShowPointer))
    table.insert(scope, button.MouseLeave:Connect(RestorePointer))

    return button
end)
