--!strict

local Packages = script.Parent.Parent.Parent.Parent.packages

local Fusion = require(Packages.fusion)
local Computed = Fusion.Computed

local Map = require(Packages.mosaic.components.map)

local CategoryOrder = require(script.categoryOrder)
local CreateItemFilter = require(script.filterItems)
local GetCollapsedState = require(script.getCollapsedState)
local GetFilterState = require(script.Parent.Parent.getFilterState)

local DefaultCategoryLayoutOrder = 999997

type Item = Map.Item
type ItemFilter = (query: string?) -> { Item }

export type MapProps = Map.MapProps
export type State = Fusion.Computed<MapProps?>

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
    return Computed(scope, function(use)
        local sortedItems = table.clone(use<<{ Item }>>(items))

        table.sort(sortedItems, function(leftItem: Item, rightItem: Item)
            return leftItem.Key < rightItem.Key
        end)

        return sortedItems
    end)
end

local function PrepareItemFilter(
    scope: Fusion.Scope,
    items: Fusion.UsedAs<{ Item }>
): Fusion.Computed<ItemFilter>
    return Computed(scope, function(use)
        return CreateItemFilter(use<<{ Item }>>(items))
    end)
end

local function FilterItems(
    scope: Fusion.Scope,
    filterState: Fusion.Value<string?>,
    itemFilter: Fusion.Computed<ItemFilter>
): Fusion.Computed<{ Item }>
    return Computed(scope, function(use)
        local usedItemFilter = use<<ItemFilter>>(itemFilter)
        local usedFilter = use<<string?>>(filterState)
        return usedItemFilter(usedFilter)
    end)
end

return function(
    scope: Fusion.Scope,
    outerScope: Fusion.Scope,
    collapsedStateScope: Fusion.Scope,
    props: CategoryProps
): State
    local name = props.Name

    local sortedItems: Fusion.UsedAs<{ Item }> =
        if props.Presorted then
            props.Items
        else
            SortItems(scope, props.Items)

    local filterState = GetFilterState(outerScope)
    local itemFilter = PrepareItemFilter(scope, sortedItems)
    local filteredItems =
        FilterItems(scope, filterState, itemFilter)

    return Computed(scope, function(use): MapProps?
        local usedFilteredItems = use<<{ Item }>>(filteredItems)
        local usedFilter = use<<string?>>(filterState)
        local hasActiveFilter =
            usedFilter ~= nil and usedFilter:match("%S") ~= nil

        if
            #usedFilteredItems == 0 and
            (not props.EmptyText or hasActiveFilter)
        then
            return nil
        end

        return {
            Header = name,
            Items = usedFilteredItems,
            LayoutOrder =
                CategoryOrder[name] or
                DefaultCategoryLayoutOrder,
            Collapsed = GetCollapsedState(collapsedStateScope, name),
            HideValues = props.HideValues,
            EmptyText = props.EmptyText
        }
    end)
end
