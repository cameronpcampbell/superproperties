--!strict

local Packages = script.Parent.Parent.packages

local Fusion = require(Packages.fusion)
local Value, Computed = Fusion.Value, Fusion.Computed

local Mosaic = require(Packages.mosaic)
local Map, Text = Mosaic.Map, Mosaic.Text

local GetProperties = require(script.getProperties)

local CategoryOrder = require(script.categoryOrder)

local DefaultCategoryLayoutOrder = 999997
local TagsCategoryLayoutOrder = 999998
local AttributesCategoryLayoutOrder = 999999

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

type PropertyItem = { Key: string, Value: any }

local function SortProperties(
    properties: { PropertyItem }
): { PropertyItem }
    table.sort(properties, function(a: PropertyItem, b: PropertyItem)
        return a.Key < b.Key
    end)

    return properties
end

local MapCollapsedStates: { [string]: Fusion.Value<boolean> } = {}

local function GetCollapsedState(scope: Fusion.Scope, categoryName: string)
    local collapsedState = MapCollapsedStates[categoryName]

    if not collapsedState then
        collapsedState = Value(scope, false)
        MapCollapsedStates[categoryName] = collapsedState
    end

    return collapsedState
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

        local maps: { Fusion.Child } = {}

        for categoryName, categoryData in properties do
            table.insert(maps, Map(scope, {
                Header = categoryName,
                Items = SortProperties(categoryData.Properties),
                LayoutOrder =
                    CategoryOrder[categoryName] or DefaultCategoryLayoutOrder,
                -- We want this state to outlive this computed's inner scope.
                Collapsed = GetCollapsedState(outerScope, categoryName)
            }))
        end

        table.insert(maps, Map(scope, {
            Header = "Tags",
            Items = GetTags(usedSelectedInstance),
            HideValues = true,
            LayoutOrder = TagsCategoryLayoutOrder,
            EmptyText = "No Tags have been added yet.",
            -- We want this state to outlive this computed's inner scope.
            Collapsed = GetCollapsedState(outerScope, "Tags"),
        }))

        table.insert(maps, Map(scope, {
            Header = "Attributes",
            Items = GetAttributes(usedSelectedInstance),
            LayoutOrder = AttributesCategoryLayoutOrder,
            EmptyText = "No Attributes have been added yet.",
            -- We want this state to outlive this computed's inner scope.
            Collapsed = GetCollapsedState(outerScope, "Attributes"),
        }))

        return maps :: Fusion.Child
    end)
end
