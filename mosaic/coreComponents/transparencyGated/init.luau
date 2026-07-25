--!strict
--!nolint LocalShadow

local Packages = script.Parent.Parent.Parent
local Fusion = require(Packages.fusion)
local Computed = Fusion.Computed

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

    local shouldRender = Computed(scope, function(use): boolean
        return use<<number>>(gatedTransparency) < 1
    end)

    return Computed(scope, function(
        use: Fusion.Use,
        renderScope: Fusion.Scope
    ): Fusion.Child
        if not use<<boolean>>(shouldRender) then return {} end

        return constructor(renderScope, props)
    end)
end)
