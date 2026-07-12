--!strict

local Packages = script.Parent.Parent.packages

local Fusion = require(Packages.fusion)
local Computed = Fusion.Computed

local Mosaic = require(Packages.mosaic)
local Text = Mosaic.Text

local Category = require(script.category)

local GetProperties = require(script.getProperties)
local ExtraCategories = require(script.extraCategories)

local function TableBulkInsert<T>(target: { T }, source: { T })
    table.move(source, 1, #source, #target + 1, target)
end

local function NoInstanceSelected(scope: Fusion.Scope): Fusion.Child
    return Text(scope, {
        Text = "No Instance selected.",
        Variant = "Secondary",
        Size = UDim2.fromScale(1, 1),
        TextXAlignment = Enum.TextXAlignment.Center,
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

return function(
    scope: Fusion.Scope,
    selectedInstanceValue: Fusion.Value<Instance>
)
    local outerScope = scope

    return Computed(scope, function(use, scope: Fusion.Scope): Fusion.Child?
        local usedSelectedInstance = use<<Instance>>(selectedInstanceValue)
        if not usedSelectedInstance then return NoInstanceSelected(scope) end

        local properties = GetProperties(usedSelectedInstance)

        local categories: { Fusion.Child } = {}

        for categoryName, categoryData in properties do
            table.insert(categories, Category(scope, outerScope, {
                Name = categoryName,
                Items = categoryData.Properties
            }))
        end

        table.insert(categories, Category(scope, outerScope, {
            Name = "Tags",
            Items = GetTags(usedSelectedInstance),
            HideValues = true,
            EmptyText = "No Tags have been added yet.",
        }))

        table.insert(categories,  Category(scope, outerScope, {
            Name = "Attributes",
            Items = GetAttributes(usedSelectedInstance),
            EmptyText = "No Attributes have been added yet.",
        }))

        local extraCategories =
            ExtraCategories[usedSelectedInstance.ClassName]

        if extraCategories then
            TableBulkInsert(categories, extraCategories(scope, outerScope))
        end

        return categories :: Fusion.Child
    end)
end
