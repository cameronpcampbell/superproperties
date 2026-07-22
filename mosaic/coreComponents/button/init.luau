--!strict

local Packages = script.Parent.Parent.Parent
local Fusion = require(Packages.fusion)
local New, OnEvent = Fusion.New, Fusion.OnEvent

local Utils = script.Parent.Parent.utils

local FusionUtils = require(Utils.fusionUtils)
local Component, CombineProps =
    FusionUtils.Component, FusionUtils.CombineProps

local Root = require(Utils.root)

local POINTER_CURSOR = "rbxasset://SystemCursors/PointingHand"

local MOUSE_LEAVE_EVENT = OnEvent "MouseLeave"

local PluginInstance = script:FindFirstAncestorOfClass("Plugin") :: Plugin?
local PluginMouse =
    if PluginInstance then PluginInstance:GetMouse() else nil

type ButtonProps = {

}

return Component<<ButtonProps>>(function(scope, props)
    local onMouseLeaveEvent = props[MOUSE_LEAVE_EVENT] :: () -> ()
    local previousMouseIcon: string? = nil
    local isHovering = false

    local function ShowPointer()
        local pluginMouse = PluginMouse
        if not pluginMouse then return end

        if not isHovering then
            isHovering = true
            previousMouseIcon = pluginMouse.Icon
        end

        pluginMouse.Icon = POINTER_CURSOR
    end

    local function RestorePointer()
        local pluginMouse = PluginMouse
        if not pluginMouse or not isHovering then return end

        isHovering = false

        if pluginMouse.Icon == POINTER_CURSOR then
            pluginMouse.Icon = previousMouseIcon or ""
        end

        previousMouseIcon = nil
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

    local button = New(scope, "TextButton") (CombineProps(props, {
        [OnEvent "Destroying"] = CleanupButton,
    })) :: TextButton

    table.insert(scope, button.MouseEnter:Connect(ShowPointer))
    table.insert(scope, button.MouseMoved:Connect(ShowPointer))
    table.insert(scope, button.MouseLeave:Connect(RestorePointer))

    return button
end)
