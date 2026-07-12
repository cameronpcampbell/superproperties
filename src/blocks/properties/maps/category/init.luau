--!strict

local Packages = script.Parent.Parent.Parent.Parent.packages

local Fusion = require(Packages.fusion)
local Computed = Fusion.Computed

local Mosaic = require(Packages.mosaic)
local Map = Mosaic.Map

local CategoryOrder = require(script.categoryOrder)
local CreateItemFilter = require(script.filterItems)
local GetCollapsedState = require(script.getCollapsedState)
local GetFilterState = require(script.Parent.Parent.getFilterState)

local DefaultCategoryLayoutOrder = 999997

type Item = { Key: string, Value: any }
type ItemFilter = (query: string?) -> { Item }

type CategoryProps = {
    Name: string,
    Items: Fusion.UsedAs<{ Item }>,
    Presorted: boolean?,
    HideValues: boolean?,
    EmptyText: string?
}

local function SortItems(
    scope: Fusion.Scope,
    items: Fusion.UsedAs<{ Item }>
): Fusion.Computed<{ Item }>
    return Computed(scope, function(use, scope)
        local sortedItems = table.clone(use<<{ Item }>>(items))

        table.sort(sortedItems, function(a: Item, b: Item)
            return a.Key < b.Key
        end)

        return sortedItems
    end)
end

local function PrepareItemFilter(
    scope: Fusion.Scope,
    items: Fusion.UsedAs<{ Item }>
): Fusion.Computed<ItemFilter>
    return Computed(scope, function(use, scope)
        return CreateItemFilter(use<<{ Item }>>(items))
    end)
end

local function FilterItems(
    scope: Fusion.Scope,
    filter: Fusion.Value<string?>,
    itemFilter: Fusion.Computed<ItemFilter>
): Fusion.Computed<{ Item }>
    return Computed(scope, function(use, scope)
        local usedItemFilter = use<<ItemFilter>>(itemFilter)
        local usedFilter = use<<string?>>(filter)
        return usedItemFilter(usedFilter)
    end)
end

return function(
    scope: Fusion.Scope,
    outerScope: Fusion.Scope,
    props: CategoryProps
)
    local name = props.Name

    local sortedItems: Fusion.UsedAs<{ Item }> =
        if props.Presorted then
            props.Items
        else
            SortItems(scope, props.Items)

    local itemFilter = PrepareItemFilter(scope, sortedItems)
    local filteredItems =
        FilterItems(scope, GetFilterState(outerScope), itemFilter)

    return Computed(scope, function(use, scope): Fusion.Child?
        local usedFilteredItems = use<<{ Item }>>(filteredItems)

        if #usedFilteredItems == 0 then
            return nil
        end

        return Map(scope, {
            Header = name,
            Items = use(usedFilteredItems),
            LayoutOrder =
                CategoryOrder[name] or
                DefaultCategoryLayoutOrder,
            -- We want this state to outlive the inner scope.
            Collapsed = GetCollapsedState(outerScope, name),
            HideValues = props.HideValues,
            EmptyText = props.EmptyText
        })
    end)
end
