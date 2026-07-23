--!strict

local Packages = script.Parent.Parent.Parent
local Fusion = require(Packages.fusion)
local OnEvent = Fusion.OnEvent

local Utils = script.Parent.Parent.utils

local FusionUtils = require(Utils.fusionUtils)
local ConstructorComponent, CombineProps, ScopedData =
    FusionUtils.ConstructorComponent, FusionUtils.CombineProps,
    FusionUtils.ScopedData

local Root = require(Utils.root)

local DEFAULT_CURSOR = "rbxasset://SystemCursors/Arrow"
local POINTER_CURSOR = "rbxasset://SystemCursors/PointingHand"

local MOUSE_LEAVE_EVENT = OnEvent "MouseLeave"
local MOUSE_BUTTON_1_UP_EVENT = OnEvent "MouseButton1Up"

local PluginInstance = script:FindFirstAncestorOfClass("Plugin") :: Plugin?
local PluginMouse =
    if PluginInstance then PluginInstance:GetMouse() else nil

type ButtonProps = {
    [any]: any,
}

return ConstructorComponent<<ButtonProps>>(function(scope, constructor, props)
    local onMouseLeaveEvent =
        (props :: { [any]: any })[MOUSE_LEAVE_EVENT] :: () -> ()
    local onMouseButton1UpEvent =
        (props :: { [any]: any })[MOUSE_BUTTON_1_UP_EVENT] :: (() -> ())?

    local cursorList =
        ScopedData(scope, "CursorList") :: { string }

    local cursorImage = POINTER_CURSOR

    local function applyCursor()
        if not PluginMouse then return end

        local activeCursor = cursorList[#cursorList]
        PluginMouse.Icon =
            if activeCursor then activeCursor
            else DEFAULT_CURSOR
    end

    local function showPointer()
        if not PluginMouse then return end

        if not table.find(cursorList, cursorImage) then
            table.insert(cursorList, cursorImage)
        end

        applyCursor()
    end

    local function restorePointer()
        local cursorIdx = table.find(cursorList, cursorImage)
        if not cursorIdx then return end

        for idx = #cursorList, cursorIdx, -1 do
            cursorList[idx] = nil
        end

        applyCursor()
    end

    local destroyRootMouseLeave = Root.AddEvent(
        scope,
        "MouseLeave",
        function()
            restorePointer()
            onMouseLeaveEvent()
            if onMouseButton1UpEvent then onMouseButton1UpEvent() end
        end
    )

    local function CleanupButton()
        restorePointer()
        destroyRootMouseLeave()
    end

    table.insert(scope, restorePointer)

    local button = constructor(scope, CombineProps(props, {
        [OnEvent "Destroying"] = CleanupButton,
    })) :: GuiButton

    table.insert(scope, button.MouseEnter:Connect(showPointer))
    table.insert(scope, button.MouseMoved:Connect(showPointer))
    table.insert(scope, button.MouseLeave:Connect(restorePointer))

    return button
end)
