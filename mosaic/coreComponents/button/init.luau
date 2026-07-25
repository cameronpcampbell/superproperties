--!strict

local Packages = script.Parent.Parent.Parent
local Fusion = require(Packages.fusion)
local OnEvent = Fusion.OnEvent

local Utils = script.Parent.Parent.utils

local FusionUtils = require(Utils.fusionUtils)
local ConstructorComponent, CombineProps, ScopedData =
    FusionUtils.ConstructorComponent, FusionUtils.CombineProps,
    FusionUtils.ScopedData

local CursorPredictor = require(Utils.cursorPredictor)

local DEFAULT_CURSOR = "rbxasset://SystemCursors/Arrow"
local POINTER_CURSOR = "rbxasset://SystemCursors/PointingHand"

local MOUSE_ENTER_EVENT = OnEvent "MouseEnter"
local MOUSE_MOVED_EVENT = OnEvent "MouseMoved"
local MOUSE_LEAVE_EVENT = OnEvent "MouseLeave"
local MOUSE_BUTTON_1_DOWN_EVENT = OnEvent "MouseButton1Down"
local MOUSE_BUTTON_1_UP_EVENT = OnEvent "MouseButton1Up"
local DESTROYING_EVENT = OnEvent "Destroying"

local PluginInstance = script:FindFirstAncestorOfClass("Plugin") :: Plugin?
local PluginMouse =
    if PluginInstance then PluginInstance:GetMouse() else nil

type Callback = (...any) -> ()

type ButtonProps = {
    [any]: any,
}

return ConstructorComponent<<ButtonProps>>(function(scope, constructor, props)
    local onMouseEnterEvent =
        (props :: { [any]: any })[MOUSE_ENTER_EVENT] :: Callback?
    local onMouseMovedEvent =
        (props :: { [any]: any })[MOUSE_MOVED_EVENT] :: Callback?
    local onMouseLeaveEvent =
        (props :: { [any]: any })[MOUSE_LEAVE_EVENT] :: Callback?
    local onMouseButton1DownEvent =
        (props :: { [any]: any })[MOUSE_BUTTON_1_DOWN_EVENT] :: Callback?
    local onMouseButton1UpEvent =
        (props :: { [any]: any })[MOUSE_BUTTON_1_UP_EVENT] :: Callback?
    local onDestroyingEvent =
        (props :: { [any]: any })[DESTROYING_EVENT] :: Callback?

    local cursorList =
        ScopedData(scope, "CursorList") :: { string }

    local cursorImage = POINTER_CURSOR
    local isHovered = false
    local predictionManaged = false
    local destroyed = false
    local predictionRegistration: CursorPredictor.Registration? = nil

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

    local function setHovered(
        nextHovered: boolean,
        position: Vector2?
    )
        if isHovered == nextHovered then
            if nextHovered and position and onMouseMovedEvent then
                onMouseMovedEvent(position.X, position.Y)
            end
            return
        end

        isHovered = nextHovered

        if nextHovered then
            showPointer()
            if position and onMouseEnterEvent then
                onMouseEnterEvent(position.X, position.Y)
            end

        else
            restorePointer()
            if onMouseLeaveEvent then onMouseLeaveEvent() end
        end
    end

    local function CleanupButton()
        if destroyed then return end
        destroyed = true
        isHovered = false
        restorePointer()

        local registration = predictionRegistration
        predictionRegistration = nil
        if registration then registration.Destroy() end

        if onDestroyingEvent then onDestroyingEvent() end
    end

    table.insert(scope, restorePointer)

    local button = constructor(scope, CombineProps(props, {
        [MOUSE_ENTER_EVENT] = function(x: number, y: number)
            if predictionManaged then return end
            setHovered(true, Vector2.new(x, y))
        end,

        [MOUSE_MOVED_EVENT] = function(x: number, y: number)
            if predictionManaged then return end
            setHovered(true, Vector2.new(x, y))
        end,

        [MOUSE_LEAVE_EVENT] = function()
            if predictionManaged then return end
            setHovered(false, nil)
        end,

        [MOUSE_BUTTON_1_DOWN_EVENT] = function(...: any)
            local registration = predictionRegistration
            if registration then registration.SetPressed(true) end

            if onMouseButton1DownEvent then
                onMouseButton1DownEvent(...)
            end
        end,

        [MOUSE_BUTTON_1_UP_EVENT] = function(...: any)
            local registration = predictionRegistration
            if registration then registration.SetPressed(false) end

            if onMouseButton1UpEvent then
                onMouseButton1UpEvent(...)
            end
        end,

        [DESTROYING_EVENT] = CleanupButton,
    })) :: GuiButton

    predictionRegistration = CursorPredictor.RegisterButton(
        scope,
        button,
        {
            Enter = function(position: Vector2)
                setHovered(true, position)
            end,

            Move = function(position: Vector2)
                setHovered(true, position)
            end,

            Leave = function()
                setHovered(false, nil)
            end,

            RootLeave = function()
                if onMouseButton1UpEvent then
                    onMouseButton1UpEvent()
                end
            end,

            ManagedChanged = function(isManaged: boolean)
                predictionManaged = isManaged
            end,
        }
    )

    return button
end)
