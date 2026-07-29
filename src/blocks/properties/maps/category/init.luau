--!strict

local Packages = script.Parent.Parent.Parent.Parent.packages

local Fusion = require(Packages.fusion)
local Computed, Observer, Peek, Value =
    Fusion.Computed, Fusion.Observer, Fusion.peek, Fusion.Value

local Mosaic = require(Packages.mosaic)
local BooleanIconButton = Mosaic.BooleanIconButton
local Map = require(Packages.mosaic.components.map)
type Item = Map.Item
local VirtualMapScrollable =
    require(Packages.mosaic.components.virtualMapScrollable)
type MapShape = VirtualMapScrollable.MapShape

local Assets = require(script.Parent.Parent.Parent.Parent.assets)
local Bookmarks = require(script.Parent.Parent.bookmarks)
local CategoryOrder = require(script.categoryOrder)
local CreateItemFilter = require(script.filterItems)
local GetCollapsedState = require(script.getCollapsedState)
local GetBookmarksOnlyState =
    require(script.Parent.Parent.getBookmarksOnlyState)
local GetFilterState = require(script.Parent.Parent.getFilterState)
local SortItemList = require(script.sortItems)

local DefaultCategoryLayoutOrder = 999997

type ItemFilter = (query: string?, items: { Item }) -> { Item }

export type Detail = (
    scope: Fusion.Scope,
    rowIdx: number
) -> Item

export type Model = {
    Shape: MapShape,
    Detail: Detail
}

export type State = Fusion.Value<Model?>

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
    local previousSortedItems: { Item }? = nil

    return Computed(scope, function(use): { Item }
        local usedItems = use<<{ Item }>>(items)
        local bookmarkedByItem: { [Item]: boolean } = {}

        for _, item in usedItems do
            local bookmarkedState =
                (item :: any).Bookmarked :: Fusion.Value<boolean>?
            bookmarkedByItem[item] =
                bookmarkedState ~= nil
                and use<<boolean>>(bookmarkedState)
        end

        local sortedItems = (SortItemList(
            usedItems :: any,
            function(item: Item): boolean
                return bookmarkedByItem[item]
            end,
            previousSortedItems :: any
        ) :: any) :: { Item }

        previousSortedItems = sortedItems
        return sortedItems
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
                childScope: Fusion.Scope<typeof(Fusion)>,
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
                    BooleanIconButton(childScope, {
                        Value = bookmarkedState,
                        TruthyIcon = Assets.BookmarkFill,
                        FalseyIcon = Assets.BookmarkOutlineThin,
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
                        end,

                        Name = "BookmarkButton"
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
    bookmarksOnlyState: Fusion.Value<boolean>,
    bookmarkable: boolean,
    items: Fusion.UsedAs<{ Item }>,
    itemFilter: Fusion.UsedAs<ItemFilter>
): Fusion.Computed<{ Item }>
    return Computed(scope, function(use: Fusion.Use): { Item }
        local usedItems = use<<{ Item }>>(items)
        local bookmarksOnly =
            use<<boolean>>(bookmarksOnlyState)
        if bookmarksOnly and not bookmarkable then
            return {} :: { Item }
        end

        local usedItemFilter = use<<ItemFilter>>(itemFilter)
        local usedFilter = use<<string?>>(filterState)
        local filteredItems =
            usedItemFilter(usedFilter, usedItems)
        if not bookmarksOnly then return filteredItems end

        local bookmarkedItems =
            table.create(#filteredItems) :: { Item }
        for _, item in filteredItems do
            local bookmarkedState =
                (item :: any).Bookmarked :: Fusion.Value<boolean>?
            if bookmarkedState
                and use<<boolean>>(bookmarkedState)
            then
                table.insert(bookmarkedItems, item)
            end
        end

        return bookmarkedItems
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

    local bookmarksOnlyState =
        GetBookmarksOnlyState(outerScope)
    local filterState = GetFilterState(outerScope)
    local itemFilter: Fusion.UsedAs<ItemFilter> =
        if props.StableKeys then
            CreateItemFilter(Peek<<{ Item }>>(itemsToFilter))
        else PrepareItemFilter(scope, itemsToFilter)
    local filteredItems =
        FilterItems(
            scope,
            filterState,
            bookmarksOnlyState,
            bookmarkable,
            itemsToFilter,
            itemFilter
        )
    local displayItems: Fusion.UsedAs<{ Item }> =
        if bookmarkable
        then SortItems(scope, filteredItems)
        else filteredItems

    local shapeTemplate: MapShape = {
        RowCount = 0,
        Header = name,
        HeaderChildren = props.HeaderChildren,
        HeaderOverlay = props.HeaderOverlay,
        ShowOnTop = props.ShowOnTop,
        LayoutOrder =
            CategoryOrder[name] or
            DefaultCategoryLayoutOrder,
        Collapsed = GetCollapsedState(collapsedStateScope, name),
        EmptyText = props.EmptyText
    }
    local categoryState = Value<<Model?>>(scope, nil)
    local categoryVisible = false
    local previousDisplayItems: { Item }? = nil

    local function refreshCategory()
        local usedDisplayItems = Peek<<{ Item }>>(displayItems)
        local usedFilter = Peek<<string?>>(filterState)
        local hasActiveFilter =
            Peek<<boolean>>(bookmarksOnlyState)
            or (
                usedFilter ~= nil
                and usedFilter:match("%S") ~= nil
            )
        local visible = not (
            #usedDisplayItems == 0 and
            (not props.EmptyText or hasActiveFilter)
        )

        if visible then
            if not categoryVisible
                or usedDisplayItems ~= previousDisplayItems
            then
                local shape = table.clone(shapeTemplate)
                shape.RowCount = #usedDisplayItems
                local detailItems = usedDisplayItems

                categoryState:set({
                    Shape = shape,
                    Detail = function(
                        _detailScope: Fusion.Scope,
                        rowIdx: number
                    ): Item
                        return assert(
                            detailItems[rowIdx],
                            `Missing {name} detail for row {rowIdx}.`
                        )
                    end
                })
            end
        elseif categoryVisible then
            categoryState:set(nil)
        end

        categoryVisible = visible
        previousDisplayItems = usedDisplayItems
    end

    -- Empty sorted lists can keep their identity across filter changes.
    -- Observe all inputs that determine category visibility.
    Observer(scope, displayItems):onChange(refreshCategory)
    Observer(scope, bookmarksOnlyState):onChange(refreshCategory)
    Observer(scope, filterState):onChange(refreshCategory)
    refreshCategory()

    return categoryState
end
