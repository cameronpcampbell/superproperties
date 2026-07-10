--!strict

local SelectionService = game:GetService("Selection")

local Packages = script.Parent.Parent.packages

local Fusion = require(Packages.fusion)

local Mosaic = require(script.Parent.Parent.mosaic)

local GetProperties = require(script.getProperties)

local CategoryOrder = require(script.categoryOrder)

type Scope = Fusion.Scope<typeof(Fusion) & typeof(Mosaic)>

local function SelectedValue(scope: Scope)
    local selectedValue = scope:Value(SelectionService:Get()[1])

    SelectionService.SelectionChanged:Connect(function()
        selectedValue:set(SelectionService:Get()[1])
    end)

    return selectedValue
end

return function(scope: Scope)
    local selectedValue = SelectedValue(scope)

    return scope:Computed(function(use, scope: Scope): { Fusion.Child }?
        local usedSelected = use<<Instance>>(selectedValue)
        if not usedSelected then return nil end

        local properties = GetProperties(usedSelected)

        local maps: { Fusion.Child } = {}

        for categoryName, categoryData in properties do
            table.insert(maps, scope:Map {
                Header = categoryName,
                Items = categoryData.Properties,
                LayoutOrder = CategoryOrder[categoryName] or 999999,
            })
        end

        return maps
    end)
end
