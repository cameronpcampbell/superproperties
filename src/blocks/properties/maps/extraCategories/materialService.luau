--!strict

local MaterialService = game:GetService("MaterialService")

local Packages = script.Parent.Parent.Parent.Parent.Parent.packages
local Fusion = require(Packages.fusion)

local Map = require(Packages.mosaic.components.map)
type Item = Map.Item

local Category = require(script.Parent.Parent.category)

local function GetIncludedMaterials()
    local includedMaterials = {}

    for _, enumItem in Enum.Material:GetEnumItems() do
        local success = pcall(
            MaterialService.GetBaseMaterialOverride,
            MaterialService, enumItem
        )
        if not success then continue end

        table.insert(includedMaterials, enumItem)
    end

    return includedMaterials
end

local IncludedMaterials = GetIncludedMaterials()
local IncludedMaterialCount = #IncludedMaterials

local function GetMaterials(): { Item }
    local materials =
        table.create(IncludedMaterialCount) :: { Item }

    for idx, enumItem in IncludedMaterials do
        materials[idx] = {
            Key = enumItem.Name,
            Value = enumItem.Name
        }
    end

    return materials
end

local MaterialItems = GetMaterials()
table.sort(MaterialItems, function(leftItem, rightItem)
    return leftItem.Key < rightItem.Key
end)

return function(
    scope: Fusion.Scope,
    outerScope: Fusion.Scope,
    collapsedStateScope: Fusion.Scope
)
    return {
        Category(scope, outerScope, collapsedStateScope, {
            Name = "Material Overrides",
            Items = MaterialItems,
            Presorted = true,
            StableKeys = true
        })
    }
end
