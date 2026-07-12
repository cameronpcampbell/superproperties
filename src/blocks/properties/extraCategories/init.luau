--!strict

local Packages = script.Parent.Parent.Parent.packages
local Fusion = require(Packages.fusion)

type ExtraCategories = {
    [string]: (
        scope: Fusion.Child,
        outerScope: Fusion.Child
    ) -> { Fusion.Child }
}

return {
    MaterialService = require(script.materialService)
} :: ExtraCategories
