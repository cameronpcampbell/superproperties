--!strict

local Packages = script.Parent.Parent.Parent
local Fusion = require(Packages.fusion)
local New, OnEvent = Fusion.New, Fusion.OnEvent

local Utils = script.Parent.Parent.utils

local FusionUtils = require(Utils.fusionUtils)
local Component, CombineProps =
    FusionUtils.Component, FusionUtils.CombineProps

local Root = require(Utils.root)

local MOUSE_LEAVE_EVENT = OnEvent "MouseLeave"

type ButtonProps = {

}

return Component<<ButtonProps>>(function(scope, props)
    local onMouseLeaveEvent = props[MOUSE_LEAVE_EVENT] :: () -> ()

    local destroyRootMouseLeave = Root.AddEvent(
        scope,
        "MouseLeave",
        onMouseLeaveEvent
    )

    return New(scope, "TextButton") (CombineProps({
        [OnEvent "Destroying"] = destroyRootMouseLeave,
    }, props))
end)
