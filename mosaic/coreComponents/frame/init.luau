--!strict

local Packages = script.Parent.Parent.Parent
local Fusion = require(Packages.fusion)
local OnEvent = Fusion.OnEvent

local Utils = script.Parent.Parent.utils

local FusionUtils = require(Utils.fusionUtils)
local ConstructorComponent, CombineProps =
    FusionUtils.ConstructorComponent, FusionUtils.CombineProps

local CursorPredictor = require(Utils.cursorPredictor)

local MOUSE_ENTER_EVENT = OnEvent "MouseEnter"
local MOUSE_MOVED_EVENT = OnEvent "MouseMoved"
local MOUSE_LEAVE_EVENT = OnEvent "MouseLeave"
local DESTROYING_EVENT = OnEvent "Destroying"

type Callback = (...any) -> ()

type FrameProps = {
    [any]: any,
}

return ConstructorComponent<<FrameProps>>(function(scope, constructor, props)
    local onMouseEnterEvent =
        (props :: { [any]: any })[MOUSE_ENTER_EVENT] :: Callback?
    local onMouseMovedEvent =
        (props :: { [any]: any })[MOUSE_MOVED_EVENT] :: Callback?
    local onMouseLeaveEvent =
        (props :: { [any]: any })[MOUSE_LEAVE_EVENT] :: Callback?
    local onDestroyingEvent =
        (props :: { [any]: any })[DESTROYING_EVENT] :: Callback?

    if not onMouseEnterEvent
        and not onMouseMovedEvent
        and not onMouseLeaveEvent
    then
        return constructor(scope, props) :: Frame
    end

    local isHovered = false
    local predictionManaged = false
    local predictionRegistration: CursorPredictor.FrameRegistration? = nil

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
            if position and onMouseEnterEvent then
                onMouseEnterEvent(position.X, position.Y)
            end
        elseif onMouseLeaveEvent then
            onMouseLeaveEvent()
        end
    end

    local function CleanupFrame()
        setHovered(false, nil)

        local registration = predictionRegistration
        predictionRegistration = nil
        if registration then registration.Destroy() end

        if onDestroyingEvent then onDestroyingEvent() end
    end

    local frame = constructor(scope, CombineProps(props, {
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

        [DESTROYING_EVENT] = CleanupFrame,
    })) :: Frame

    predictionRegistration = CursorPredictor.RegisterFrame(
        scope,
        frame,
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

    return frame
end)
