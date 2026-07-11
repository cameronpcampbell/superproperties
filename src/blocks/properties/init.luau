--!strict

local SelectionService = game:GetService("Selection")

local Packages = script.Parent.Parent.packages

local Fusion = require(Packages.fusion)
local Value, Computed = Fusion.Value, Fusion.Computed

local Mosaic = require(Packages.mosaic)
local Map, Text = Mosaic.Map, Mosaic.Text

local GetProperties = require(script.getProperties)

local CategoryOrder = require(script.categoryOrder)

local function SelectedValue(scope: Fusion.Scope)
    local selectedValue = Value(scope, SelectionService:Get()[1])

    SelectionService.SelectionChanged:Connect(function()
        selectedValue:set(SelectionService:Get()[1])
    end)

    return selectedValue
end

local function NoInstanceSelected(scope: Fusion.Scope): Fusion.Child
    return Text(scope, {
        Text = "No Instance selected.",
        Variant = "Secondary",
        Size = UDim2.fromScale(1, 1)
    })
end

return function(scope: Fusion.Scope)
    local selectedValue = SelectedValue(scope)

    return Computed(scope, function(use, scope: Fusion.Scope): Fusion.Child?
        local usedSelected = use<<Instance>>(selectedValue)
        if not usedSelected then return NoInstanceSelected(scope) end

        local properties = GetProperties(usedSelected)

        local maps: { Fusion.Child } = {}

        for categoryName, categoryData in properties do
            table.insert(maps, Map(scope, {
                Header = categoryName,
                Items = categoryData.Properties,
                LayoutOrder = CategoryOrder[categoryName] or 999999,
            }))
        end

        table.insert(maps, Map(scope, {
            Header = "Tags",
            Items = {},
            LayoutOrder = CategoryOrder["Tags"] or 999999,
            EmptyText = "No Tags have been added yet."
        }))

        table.insert(maps, Map(scope, {
            Header = "Attributes",
            Items = {},
            LayoutOrder = CategoryOrder["Attributes"] or 999999,
            EmptyText = "No Attributes have been added yet."
        }))

        return maps :: Fusion.Child
    end)
end
