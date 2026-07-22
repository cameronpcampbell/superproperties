--!strict

local Packages = script.Parent.Parent.Parent.Parent.packages

local Fusion = require(Packages.fusion)
local Computed, Observer, Peek, Value =
    Fusion.Computed, Fusion.Observer, Fusion.peek, Fusion.Value

local Map = require(Packages.mosaic.components.map)

local CategoryOrder = require(script.categoryOrder)
local CreateItemFilter = require(script.filterItems)
local GetCollapsedState = require(script.getCollapsedState)
local GetFilterState = require(script.Parent.Parent.getFilterState)

local DefaultCategoryLayoutOrder = 999997

type Item = Map.Item
type ItemFilter = (query: string?, items: { Item }) -> { Item }

export type MapProps = Map.MapProps
export type State = Fusion.Value<MapProps?>

type CategoryProps = {
    Name: string,
    Items: Fusion.UsedAs<{ Item }>,
    Presorted: boolean?,
    StableKeys: boolean?,
    EmptyText: string?,
    HeaderChildren: { Fusion.Child }?,
    HeaderOverlay: Fusion.Child?,
    ShowOnTop: Fusion.UsedAs<boolean>?
}

local function GetItemLabel(item: Item): string
    return if item.Key ~= nil then item.Key else tostring(item.Value)
end

local function SortItems(
    scope: Fusion.Scope,
    items: Fusion.UsedAs<{ Item }>
): Fusion.Computed<{ Item }>
    return Computed(scope, function(use)
        local sortedItems = table.clone(use<<{ Item }>>(items))

        table.sort(sortedItems, function(leftItem: Item, rightItem: Item)
            return GetItemLabel(leftItem) < GetItemLabel(rightItem)
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
    items: Fusion.UsedAs<{ Item }>,
    itemFilter: Fusion.UsedAs<ItemFilter>
): Fusion.Computed<{ Item }>
    return Computed(scope, function(use)
        local usedItems = use<<{ Item }>>(items)
        local usedItemFilter = use<<ItemFilter>>(itemFilter)
        local usedFilter = use<<string?>>(filterState)
        return usedItemFilter(usedFilter, usedItems)
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
    local itemFilter: Fusion.UsedAs<ItemFilter> =
        if props.StableKeys then
            CreateItemFilter(Peek<<{ Item }>>(sortedItems))
        else PrepareItemFilter(scope, sortedItems)
    local filteredItems =
        FilterItems(scope, filterState, sortedItems, itemFilter)

    -- Keep this table stable so item changes update the existing map layout.
    -- The category state only changes when its visibility changes.
    local mapProps = {
        Header = name,
        HeaderChildren = props.HeaderChildren,
        HeaderOverlay = props.HeaderOverlay,
        ShowOnTop = props.ShowOnTop,
        Items = filteredItems,
        LayoutOrder =
            CategoryOrder[name] or
            DefaultCategoryLayoutOrder,
        Collapsed = GetCollapsedState(collapsedStateScope, name),
        EmptyText = props.EmptyText,
    }
    local categoryState = Value<<MapProps?>>(scope, nil)
    local categoryVisible = false

    local function refreshVisibility()
        local usedFilteredItems = Peek<<{ Item }>>(filteredItems)
        local usedFilter = Peek<<string?>>(filterState)
        local hasActiveFilter =
            usedFilter ~= nil and usedFilter:match("%S") ~= nil
        local visible = not (
            #usedFilteredItems == 0 and
            (not props.EmptyText or hasActiveFilter)
        )

        if visible == categoryVisible then return end
        categoryVisible = visible
        categoryState:set(if visible then mapProps else nil)
    end

    Observer(scope, filteredItems):onChange(refreshVisibility)
    refreshVisibility()

    return categoryState
end
