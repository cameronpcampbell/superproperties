--!strict
--!nolint LocalShadow

local Packages = script.Parent.Parent.Parent
local Fusion = require(Packages.fusion)
local Computed, Observer, Peek, Value =
    Fusion.Computed, Fusion.Observer, Fusion.peek, Fusion.Value

local Utils = script.Parent.Parent.utils

local FusionUtils = require(Utils.fusionUtils)
local ConstructorComponent = FusionUtils.ConstructorComponent

local TableUtils = require(Utils.tableUtils)
local TableExtract = TableUtils.Extract

export type Props = {
    GatedTransparencyProperty: string?,
    [any]: any
}

return ConstructorComponent<<Props>>(function(scope, constructor, props)
    local props, gatedTransparencyProperty = TableExtract(
        props,
        "GatedTransparencyProperty",
        "BackgroundTransparency"
    )
    local gatedTransparency =
        (props :: { [any]: any })[gatedTransparencyProperty] or 0

    local renderState = Value(
        scope,
        Peek<<number>>(gatedTransparency) < 1
    )
    local pendingRenderState = Peek<<boolean>>(renderState)
    local renderUpdateScheduled = false
    local renderStateAlive = true

    Observer(scope, gatedTransparency):onChange(function()
        local nextRenderState =
            Peek<<number>>(gatedTransparency) < 1
        if pendingRenderState == nextRenderState then return end

        pendingRenderState = nextRenderState
        if renderUpdateScheduled then return end

        -- Animated states update while Fusion's graph is busy. Reconcile the
        -- constructor afterward so mounting cannot add dependencies during
        -- the animation traversal that triggered it.
        renderUpdateScheduled = true
        task.defer(function()
            renderUpdateScheduled = false
            if not renderStateAlive then return end
            if Peek<<boolean>>(renderState) == pendingRenderState then
                return
            end

            renderState:set(pendingRenderState)
        end)
    end)

    table.insert(scope, function()
        renderStateAlive = false
    end)

    return Computed(scope, function(
        use: Fusion.Use,
        renderScope: Fusion.Scope
    ): Fusion.Child
        if not use<<boolean>>(renderState) then return {} end

        return constructor(renderScope, props)
    end)
end)
