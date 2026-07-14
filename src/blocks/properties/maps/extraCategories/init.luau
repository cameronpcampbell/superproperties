--!strict

local Packages = script.Parent.Parent.Parent.Parent.packages
local Fusion = require(Packages.fusion)

local Category = require(script.Parent.category)

type ExtraCategories = {
    [string]: (
        scope: Fusion.Scope,
        outerScope: Fusion.Scope,
        collapsedStateScope: Fusion.Scope
    ) -> { Category.State }
}

return {
    MaterialService = require(script.materialService)
} :: ExtraCategories
