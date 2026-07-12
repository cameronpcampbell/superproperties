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

local function GetTags(
    instance: Instance
): {{ Key: string, Value: nil }}
    local tags = instance:GetTags()
    local tagItems =
        table.create(#tags) :: {{ Key: string, Value: nil }}

    for idx, tag in tags do
        tagItems[idx] = {
            Key = tag
        }
    end

    return tagItems
end

local function GetAttributes(
    instance: Instance
): {{ Key: string, Value: any }}
    local attributes = instance:GetAttributes()
    local attributeItems ={} :: {{ Key: string, Value: any }}

    local idx = 1
    for attributeName, attributeValue in attributes do
        attributeItems[idx] = {
            Key = attributeName,
            Value = attributeValue
        }

        idx += 1
    end

    return attributeItems
end

return function(scope: Fusion.Scope)
    local selectedInstValue = SelectedValue(scope)

    return Computed(scope, function(use, scope: Fusion.Scope): Fusion.Child?
        local usedSelectedInst = use<<Instance>>(selectedInstValue)
        if not usedSelectedInst then return NoInstanceSelected(scope) end

        local properties = GetProperties(usedSelectedInst)

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
            Items = GetTags(usedSelectedInst),
            HideValues = true,
            LayoutOrder = CategoryOrder["Tags"] or 999999,
            EmptyText = "No Tags have been added yet."
        }))

        table.insert(maps, Map(scope, {
            Header = "Attributes",
            Items = GetAttributes(usedSelectedInst),
            LayoutOrder = CategoryOrder["Attributes"] or 999999,
            EmptyText = "No Attributes have been added yet."
        }))

        return maps :: Fusion.Child
    end)
end
