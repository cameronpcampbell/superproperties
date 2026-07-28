--!strict

local Packages = script.Parent.Parent.Parent.Parent.packages

local Fusion = require(Packages.fusion)
local Computed, Observer, Peek, Value =
    Fusion.Computed, Fusion.Observer, Fusion.peek, Fusion.Value

local Map = require(Packages.mosaic.components.map)
type Item = Map.Item

local BookmarkButton = require(script.Parent.Parent.bookmarkButton)
local Bookmarks = require(script.Parent.Parent.bookmarks)
local CategoryOrder = require(script.categoryOrder)
local CreateItemFilter = require(script.filterItems)
local GetCollapsedState = require(script.getCollapsedState)
local GetFilterState = require(script.Parent.Parent.getFilterState)
local SortItemList = require(script.sortItems)

local DefaultCategoryLayoutOrder = 999997

type ItemFilter = (query: string?, items: { Item }) -> { Item }

export type MapProps = Map.MapProps
export type State = Fusion.Value<MapProps?>

type CategoryProps = {
    Name: string,
    Items: Fusion.UsedAs<{ Item }>,
    Bookmarkable: boolean?,
    Presorted: boolean?,
    StableKeys: boolean?,
    EmptyText: string?,
    HeaderChildren: Map.HeaderChildren?,
    HeaderOverlay: Fusion.Child?,
    ShowOnTop: Fusion.UsedAs<boolean>?
}

local function SortItems(
    scope: Fusion.Scope,
    items: Fusion.UsedAs<{ Item }>
): Fusion.Computed<{ Item }>
    return Computed(scope, function(use)
        local usedItems = use<<{ Item }>>(items)
        local bookmarkedByItem: { [Item]: boolean } = {}

        for _, item in usedItems do
            local bookmarkedState =
                (item :: any).Bookmarked :: Fusion.Value<boolean>?
            bookmarkedByItem[item] =
                bookmarkedState ~= nil
                and use<<boolean>>(bookmarkedState)
        end

        return (SortItemList(
            usedItems :: any,
            function(item: Item): boolean
                return bookmarkedByItem[item]
            end
        ) :: any) :: { Item }
    end)
end

local function DecorateBookmarkItems(
    scope: Fusion.Scope,
    outerScope: Fusion.Scope,
    items: Fusion.UsedAs<{ Item }>
): Fusion.Computed<{ Item }>
    return Computed(scope, function(use): { Item }
        local usedItems = use<<{ Item }>>(items)
        local decoratedItems =
            table.create(#usedItems) :: { Item }

        for itemIdx, item in usedItems do
            local bookmarkKey =
                (item :: any).BookmarkKey :: string?
            if not bookmarkKey then
                decoratedItems[itemIdx] = item
                continue
            end

            local usedBookmarkKey = bookmarkKey
            local bookmarkedState =
                Bookmarks.GetState(outerScope, usedBookmarkKey)
            local decoratedItem = table.clone(item)
            local originalKeyChildren = item.KeyChildren

            decoratedItem.KeyChildren = function(
                childScope: Fusion.Scope,
                hoverTransparency: Fusion.UsedAs<number>
            ): { Fusion.Child }
                local bookmarkTransparency = Computed(
                    childScope,
                    function(use: Fusion.Use): number
                        if use<<boolean>>(bookmarkedState) then
                            return 0
                        end

                        return use<<number>>(hoverTransparency)
                    end
                )
                local decoratedKeyChildren = {
                    BookmarkButton(childScope, {
                        Bookmarked = bookmarkedState,
                        Transparency = bookmarkTransparency,

                        OnChanged = function(bookmarked: boolean)
                            local success, err = Bookmarks.Set(
                                outerScope,
                                usedBookmarkKey,
                                bookmarked
                            )
                            if success then return end

                            warn(
                                `Could not save bookmark {usedBookmarkKey}: {err}`
                            )
                        end
                    })
                } :: { Fusion.Child }

                if originalKeyChildren then
                    local keyChildren = originalKeyChildren(
                        childScope,
                        hoverTransparency
                    )
                    table.move(
                        keyChildren,
                        1,
                        #keyChildren,
                        #decoratedKeyChildren + 1,
                        decoratedKeyChildren
                    )
                end

                return decoratedKeyChildren
            end

            local bookmarkableItem = decoratedItem :: any
            bookmarkableItem.Bookmarked = bookmarkedState
            decoratedItems[itemIdx] = decoratedItem
        end

        return decoratedItems
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
    local bookmarkable = props.Bookmarkable == true

    local preparedItems: Fusion.UsedAs<{ Item }> =
        if bookmarkable
        then DecorateBookmarkItems(scope, outerScope, props.Items)
        else props.Items
    local itemsToFilter: Fusion.UsedAs<{ Item }> =
        if bookmarkable or props.Presorted
        then preparedItems
        else SortItems(scope, preparedItems)

    local filterState = GetFilterState(outerScope)
    local itemFilter: Fusion.UsedAs<ItemFilter> =
        if props.StableKeys then
            CreateItemFilter(Peek<<{ Item }>>(itemsToFilter))
        else PrepareItemFilter(scope, itemsToFilter)
    local filteredItems =
        FilterItems(scope, filterState, itemsToFilter, itemFilter)
    local displayItems: Fusion.UsedAs<{ Item }> =
        if bookmarkable
        then SortItems(scope, filteredItems)
        else filteredItems

    -- Keep this table stable so item changes update the existing map layout.
    -- The category state only changes when its visibility changes.
    local mapProps = {
        Header = name,
        HeaderChildren = props.HeaderChildren,
        HeaderOverlay = props.HeaderOverlay,
        ShowOnTop = props.ShowOnTop,
        Items = displayItems,
        LayoutOrder =
            CategoryOrder[name] or
            DefaultCategoryLayoutOrder,
        Collapsed = GetCollapsedState(collapsedStateScope, name),
        EmptyText = props.EmptyText,
    }
    local categoryState = Value<<MapProps?>>(scope, nil)
    local categoryVisible = false

    local function refreshVisibility()
        local usedDisplayItems = Peek<<{ Item }>>(displayItems)
        local usedFilter = Peek<<string?>>(filterState)
        local hasActiveFilter =
            usedFilter ~= nil and usedFilter:match("%S") ~= nil
        local visible = not (
            #usedDisplayItems == 0 and
            (not props.EmptyText or hasActiveFilter)
        )

        if visible == categoryVisible then return end
        categoryVisible = visible
        categoryState:set(if visible then mapProps else nil)
    end

    Observer(scope, displayItems):onChange(refreshVisibility)
    refreshVisibility()

    return categoryState
end
