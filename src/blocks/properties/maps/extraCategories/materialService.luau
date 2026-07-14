--!strict

local MaterialService = game:GetService("MaterialService")

local Packages = script.Parent.Parent.Parent.Parent.Parent.packages
local Fusion = require(Packages.fusion)

local Category = require(script.Parent.Parent.category)

local function GetIncludedMaterials()
    local includedMaterials = {}

    for _, enumItem in Enum.Material:GetEnumItems() do
        local ok = pcall(
            MaterialService.GetBaseMaterialOverride,
            MaterialService, enumItem
        )
        if not ok then continue end

        table.insert(includedMaterials, enumItem)
    end

    return includedMaterials
end

local IncludedMaterials = GetIncludedMaterials()
local IncludedMaterialsLen = #IncludedMaterials

local function GetMaterials(): {{ Key: string, Value: string }}
    local materials =
        table.create(IncludedMaterialsLen) :: {{ Key: string, Value: string }}

    for idx, enumItem in IncludedMaterials do
        materials[idx] = {
            Key = enumItem.Name,
            Value = enumItem.Name
        }
    end

    return materials
end

return function(
    scope: Fusion.Scope,
    outerScope: Fusion.Scope,
    collapsedStateScope: Fusion.Scope
)
    return {
        Category(scope, outerScope, collapsedStateScope, {
            Name = "Material Overrides",
            Items = GetMaterials()
        })
    }
end
