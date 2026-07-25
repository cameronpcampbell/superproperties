--!strict
--!nolint LocalShadow

local Packages = script.Parent.Parent.Parent
local Fusion = require(Packages.fusion)
local New, Value, Computed, OnEvent =
    Fusion.New, Fusion.Value, Fusion.Computed, Fusion.OnEvent

local Utils = script.Parent.Parent.utils

local FusionUtils = require(Utils.fusionUtils)
local Component, CombineProps, ScopedData =
    FusionUtils.Component, FusionUtils.CombineProps,
    FusionUtils.ScopedData

local TableUtils = require(Utils.tableUtils)
local TableExtract = TableUtils.Extract

local CursorPredictor = require(Utils.cursorPredictor)

local DEFAULT_CURSOR = "rbxasset://SystemCursors/Arrow"
local TEXT_CURSOR = "rbxasset://SystemCursors/IBeam"

type InputProps = {
    TextTruncate: Fusion.UsedAs<Enum.TextTruncate>?,
    [any]: any
}

type Callback = (...any) -> ()
type FocusedCallback = () -> ()
type FocusLostCallback = (boolean, InputObject?) -> ()

local FocusedEvent = OnEvent "Focused"
local FocusLostEvent = OnEvent "FocusLost"
local MOUSE_ENTER_EVENT = OnEvent "MouseEnter"
local MOUSE_MOVED_EVENT = OnEvent "MouseMoved"
local MOUSE_LEAVE_EVENT = OnEvent "MouseLeave"
local DESTROYING_EVENT = OnEvent "Destroying"

local PluginInstance = script:FindFirstAncestorOfClass("Plugin") :: Plugin?
local PluginMouse =
    if PluginInstance then PluginInstance:GetMouse() else nil

return Component<<InputProps>>(function(scope, props)
    local props, textTruncate =
        TableExtract(props, "TextTruncate", Enum.TextTruncate.AtEnd)
    local props, focusedCallback = TableExtract(props, FocusedEvent)
    local props, focusLostCallback = TableExtract(props, FocusLostEvent)
    local props, mouseEnterCallback =
        TableExtract(props, MOUSE_ENTER_EVENT)
    local props, mouseMovedCallback =
        TableExtract(props, MOUSE_MOVED_EVENT)
    local props, mouseLeaveCallback =
        TableExtract(props, MOUSE_LEAVE_EVENT)
    local props, destroyingCallback =
        TableExtract(props, DESTROYING_EVENT)

    local onFocused = focusedCallback :: FocusedCallback?
    local onFocusLost = focusLostCallback :: FocusLostCallback?
    local onMouseEnter = mouseEnterCallback :: Callback?
    local onMouseMoved = mouseMovedCallback :: Callback?
    local onMouseLeave = mouseLeaveCallback :: Callback?
    local onDestroying = destroyingCallback :: Callback?
    local isFocusState = Value(scope, false)
    local cursorList =
        ScopedData(scope, "CursorList") :: { string }

    local isHovered = false
    local predictionManaged = false
    local predictionRegistration: CursorPredictor.InputRegistration? = nil

    local computedTextTruncate = Computed(scope, function(use)
        return
            if use<<boolean>>(isFocusState) then
                Enum.TextTruncate.None
            else
                use<<Enum.TextTruncate>>(textTruncate)
    end)

    local function applyCursor()
        if not PluginMouse then return end

        local activeCursor = cursorList[#cursorList]
        PluginMouse.Icon =
            if activeCursor then activeCursor
            else DEFAULT_CURSOR
    end

    local function showTextCursor()
        if not PluginMouse then return end

        if not table.find(cursorList, TEXT_CURSOR) then
            table.insert(cursorList, TEXT_CURSOR)
        end

        applyCursor()
    end

    local function restoreCursor()
        local cursorIdx = table.find(cursorList, TEXT_CURSOR)
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
            if nextHovered and position and onMouseMoved then
                onMouseMoved(position.X, position.Y)
            end
            return
        end

        isHovered = nextHovered

        if nextHovered then
            showTextCursor()
            if position and onMouseEnter then
                onMouseEnter(position.X, position.Y)
            end
        else
            restoreCursor()
            if onMouseLeave then onMouseLeave() end
        end
    end

    local function CleanupInput()
        setHovered(false, nil)

        local registration = predictionRegistration
        predictionRegistration = nil
        if registration then registration.Destroy() end

        if onDestroying then onDestroying() end
    end

    table.insert(scope, restoreCursor)

    local input = New(scope, "TextBox")(CombineProps({
        TextTruncate = computedTextTruncate,

        [FocusedEvent] = function()
            isFocusState:set(true)
            if onFocused then onFocused() end
        end,

        [FocusLostEvent] = function(
            enterPressed: boolean,
            inputThatCausedFocusLoss: InputObject?
        )
            isFocusState:set(false)
            if onFocusLost then
                onFocusLost(enterPressed, inputThatCausedFocusLoss)
            end
        end,

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

        [DESTROYING_EVENT] = CleanupInput,
    }, props)) :: TextBox

    predictionRegistration = CursorPredictor.RegisterInput(
        scope,
        input,
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

            ManagedChanged = function(isManaged: boolean)
                predictionManaged = isManaged
            end,
        }
    )

    return input
end)
