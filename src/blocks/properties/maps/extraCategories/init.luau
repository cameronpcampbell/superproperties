--!strict

local Packages = script.Parent.Parent.Parent.Parent.packages
local Fusion = require(Packages.fusion)

local Category = require(script.Parent.category)

type ExtraCategory = (
    scope: Fusion.Scope,
    outerScope: Fusion.Scope,
    collapsedStateScope: Fusion.Scope
) -> { Category.State }
type ExtraCategories = { [string]: ExtraCategory }

local materialServiceCategories: ExtraCategory? = nil
local function GetMaterialServiceCategories(
    scope: Fusion.Scope,
    outerScope: Fusion.Scope,
    collapsedStateScope: Fusion.Scope
): { Category.State }
    local categoryFactory = materialServiceCategories
    if categoryFactory then
        return categoryFactory(
            scope,
            outerScope,
            collapsedStateScope
        )
    end

    local loadedCategoryFactory: ExtraCategory =
        require(script.materialService)
    materialServiceCategories = loadedCategoryFactory
    return loadedCategoryFactory(
        scope,
        outerScope,
        collapsedStateScope
    )
end

return {
    MaterialService = GetMaterialServiceCategories
} :: ExtraCategories
