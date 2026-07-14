--!strict

local Packages = script.Parent.Parent.Parent.packages

local Fusion = require(Packages.fusion)
local Children, Computed, New =
    Fusion.Children, Fusion.Computed, Fusion.New

local Mosaic = require(Packages.mosaic)
local Text, VirtualMapScrollable =
    Mosaic.Text, Mosaic.VirtualMapScrollable

local Category = require(script.category)
type CategoryState = Category.State
type MapProps = Category.MapProps

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

local function GetCategoryStates(
    scope: Fusion.Scope,
    outerScope: Fusion.Scope,
    collapsedStateScope: Fusion.Scope,
    instance: Instance
): { CategoryState }
    local properties = GetProperties(instance)
    local categories: { CategoryState } = {}

    for categoryName, categoryData in properties do
        table.insert(categories, Category(scope, outerScope, collapsedStateScope, {
            Name = categoryName,
            Items = categoryData.Properties,
            Presorted = true
        }))
    end

    table.insert(categories, Category(scope, outerScope, collapsedStateScope, {
        Name = "Tags",
        Items = GetTags(instance),
        HideValues = true,
        EmptyText = "No Tags have been added yet.",
    }))

    table.insert(categories, Category(scope, outerScope, collapsedStateScope, {
        Name = "Attributes",
        Items = GetAttributes(instance),
        EmptyText = "No Attributes have been added yet.",
    }))

    local extraCategories = ExtraCategories[instance.ClassName]

    if extraCategories then
        TableBulkInsert(
            categories,
            extraCategories(scope, outerScope, collapsedStateScope)
        )
    end

    return categories
end

return function(
    scope: Fusion.Scope,
    selectedInstanceValue: Fusion.Value<Instance>
)
    local outerScope = scope
    local collapsedStateScope = Fusion.innerScope(outerScope)
    local mapsScope = Fusion.innerScope(outerScope)

    local computeCategoryStates = Computed(mapsScope, function(
        use,
        scope: Fusion.Scope
    ): { CategoryState }
        local usedSelectedInstance = use<<Instance>>(selectedInstanceValue)
        if not usedSelectedInstance then return {} end

        return GetCategoryStates(
            scope,
            outerScope,
            collapsedStateScope,
            usedSelectedInstance
        )
    end)

    local computeMapProps = Computed(mapsScope, function(use): { MapProps }
        local categoryStates =
            use<<{ CategoryState }>>(computeCategoryStates)
        local maps = table.create(#categoryStates) :: { MapProps }
        local mapCount = 0

        for _, categoryState in categoryStates do
            local mapProps = use<<MapProps?>>(categoryState)
            if not mapProps then continue end

            mapCount += 1
            maps[mapCount] = mapProps
        end

        return maps
    end)

    local computeNoInstanceSelected = Computed(mapsScope, function(
        use,
        scope: Fusion.Scope
    ): Fusion.Child?
        if use<<Instance>>(selectedInstanceValue) then return nil end
        return NoInstanceSelected(scope)
    end)

    return VirtualMapScrollable(mapsScope, {
        Maps = computeMapProps,

        [Children] = {
            computeNoInstanceSelected,

            New(mapsScope, "UIListLayout") {
                FillDirection = Enum.FillDirection.Vertical,
                SortOrder = Enum.SortOrder.LayoutOrder,
                Padding = UDim.new(0, 4)
            }
        }
    })
end
