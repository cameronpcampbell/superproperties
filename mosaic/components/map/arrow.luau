--!strict

local Packages = script.Parent.Parent.Parent.Parent

local Fusion = require(Packages.fusion)
local Peek, OnEvent, Computed, Tween =
    Fusion.peek, Fusion.OnEvent, Fusion.Computed, Fusion.Tween

local Components = script.Parent.Parent
local IconButton = require(Components.iconButton)

local Assets = require(script.Parent.Parent.Parent.assets)
local MapTweenInfo = require(script.Parent.animation)

export type ArrowProps = {
    CollapsedState: Fusion.Value<boolean>,
    Variant: "Primary" | "Secondary"?,
    Thin: boolean?,
    LayoutOrder: number?
}

return function(scope: Fusion.Scope, props: ArrowProps)
    local collapsedState = props.CollapsedState

    return IconButton(scope, {
        Image = if props.Thin then
            Assets.ArrowThin
            else Assets.Arrow,
        Variant = props.Variant,
        LayoutOrder = props.LayoutOrder,
        Rotation = Tween<<number>>(
            scope,
            Computed(scope, function(use: Fusion.Use): number
                return
                    if use<<boolean>>(collapsedState) then -90
                    else 0
            end),
            MapTweenInfo
        ),

        [OnEvent "MouseButton1Click"] = function()
            collapsedState:set(not Peek<<boolean>>(collapsedState))
        end
    })
end
