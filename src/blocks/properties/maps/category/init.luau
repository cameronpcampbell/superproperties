--!strict

local Packages = script.Parent.Parent.Parent.Parent.packages

local Fusion = require(Packages.fusion)
local Computed, InnerScope, Observer, Peek, Value =
    Fusion.Computed, Fusion.innerScope, Fusion.Observer, Fusion.peek,
    Fusion.Value

local Mosaic = require(Packages.mosaic)
local BooleanIconButton = Mosaic.BooleanIconButton
local Map = require(Packages.mosaic.components.map)
type Item = Map.Item
type ValueType = Map.ValueType
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

export type RowDescriptor = {
    Id: string,
    Key: string,
    BookmarkKey: string?,
    ValueType: ValueType?,
    Hydrate: (scope: Fusion.Scope) -> Item
}

type RowFilter = (
    query: string?,
    rows: { RowDescriptor }
) -> { RowDescriptor }
type GetBookmarkState = (
    row: RowDescriptor
) -> Fusion.Value<boolean>?

type HydratedRow = {
    Item: Item,
    Scope: Fusion.Scope
}

export type Detail = (
    scope: Fusion.Scope,
    rowIdx: number
) -> Item

export type Model = {
    Shape: MapShape,
    Detail: Detail
}

export type State = Fusion.Value<Model?>

export type CategoryProps = {
    Name: string,
    Items: Fusion.UsedAs<{ Item }>?,
    Rows: Fusion.UsedAs<{ RowDescriptor }>?,
    Bookmarkable: boolean?,
    Presorted: boolean?,
    StableKeys: boolean?,
    EmptyText: string?,
    HeaderChildren: Map.HeaderChildren?,
    HeaderOverlay: Fusion.Child?,
    ShowOnTop: Fusion.UsedAs<boolean>?
}

local function HasTextFilter(query: string?): boolean
    return query ~= nil and query:match("%S") ~= nil
end

local function CreateRowsFromItems(
    scope: Fusion.Scope,
    items: Fusion.UsedAs<{ Item }>
): Fusion.Computed<{ RowDescriptor }>
    local rowsByItem: { [Item]: RowDescriptor } = {}

    return Computed(scope, function(use): { RowDescriptor }
        local usedItems = use<<{ Item }>>(items)
        local rows =
            table.create(#usedItems) :: { RowDescriptor }

        for itemIdx, item in usedItems do
            local row = rowsByItem[item]
            if not row then
                local itemValueType = item.ValueType
                local bookmarkKey =
                    (item :: any).BookmarkKey :: string?
                local wrappedItem = item

                row = {
                    Id = bookmarkKey or item.Key,
                    Key = item.Key,
                    BookmarkKey = bookmarkKey,
                    ValueType =
                        itemValueType
                        or typeof(Peek<<any?>>(item.Value)),
                    Hydrate = function(
                        _hydrationScope: Fusion.Scope
                    ): Item
                        return wrappedItem
                    end
                }
                rowsByItem[item] = row
            end

            rows[itemIdx] = row
        end

        return rows
    end)
end

local function SortRows(
    scope: Fusion.Scope,
    rows: Fusion.UsedAs<{ RowDescriptor }>,
    getBookmarkState: GetBookmarkState
): Fusion.Computed<{ RowDescriptor }>
    local previousSortedRows: { RowDescriptor }? = nil

    return Computed(scope, function(use): { RowDescriptor }
        local usedRows = use<<{ RowDescriptor }>>(rows)
        local bookmarkedByRow: { [RowDescriptor]: boolean } = {}

        for _, row in usedRows do
            local bookmarkedState = getBookmarkState(row)
            bookmarkedByRow[row] =
                bookmarkedState ~= nil
                and use<<boolean>>(bookmarkedState)
        end

        local sortedRows = (SortItemList(
            usedRows :: any,
            function(row: RowDescriptor): boolean
                return bookmarkedByRow[row]
            end,
            previousSortedRows :: any
        ) :: any) :: { RowDescriptor }

        previousSortedRows = sortedRows
        return sortedRows
    end)
end

local function DecorateBookmarkItem(
    outerScope: Fusion.Scope,
    row: RowDescriptor,
    item: Item,
    bookmarkedState: Fusion.Value<boolean>
): Item
    local bookmarkKey = assert(row.BookmarkKey)
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
                        bookmarkKey,
                        bookmarked
                    )
                    if success then return end

                    warn(
                        `Could not save bookmark {bookmarkKey}: {err}`
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
    bookmarkableItem.BookmarkKey = bookmarkKey
    bookmarkableItem.Bookmarked = bookmarkedState
    return decoratedItem
end

local function FilterRows(
    scope: Fusion.Scope,
    filterState: Fusion.Value<string?>,
    bookmarksOnlyState: Fusion.Value<boolean>,
    bookmarkable: boolean,
    rows: Fusion.UsedAs<{ RowDescriptor }>,
    getBookmarkState: GetBookmarkState,
    getRowFilter: ({ RowDescriptor }) -> RowFilter
): Fusion.Computed<{ RowDescriptor }>
    return Computed(scope, function(use: Fusion.Use): { RowDescriptor }
        local usedRows = use<<{ RowDescriptor }>>(rows)
        local bookmarksOnly =
            use<<boolean>>(bookmarksOnlyState)
        if bookmarksOnly and not bookmarkable then
            return {} :: { RowDescriptor }
        end

        local usedFilter = use<<string?>>(filterState)
        local filteredRows = usedRows
        if HasTextFilter(usedFilter) then
            local rowFilter = getRowFilter(usedRows)
            filteredRows = rowFilter(usedFilter, usedRows)
        end
        if not bookmarksOnly then return filteredRows end

        local bookmarkedRows =
            table.create(#filteredRows) :: { RowDescriptor }
        for _, row in filteredRows do
            local bookmarkedState = getBookmarkState(row)
            if bookmarkedState
                and use<<boolean>>(bookmarkedState)
            then
                table.insert(bookmarkedRows, row)
            end
        end

        return bookmarkedRows
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

    local suppliedRows = props.Rows
    local suppliedItems = props.Items
    assert(
        (suppliedRows == nil) ~= (suppliedItems == nil),
        "Category requires exactly one of Rows or Items."
    )

    local sourceRows: Fusion.UsedAs<{ RowDescriptor }> =
        if suppliedRows ~= nil
        then suppliedRows
        else CreateRowsFromItems(scope, assert(suppliedItems))
    local sourceRowsState = Computed(scope, function(
        use: Fusion.Use
    ): { RowDescriptor }
        return use<<{ RowDescriptor }>>(sourceRows)
    end)

    local bookmarkedStatesByKey: {
        [string]: Fusion.Value<boolean>
    } = {}
    local function getBookmarkState(
        row: RowDescriptor
    ): Fusion.Value<boolean>?
        if not bookmarkable or not row.BookmarkKey then return nil end

        local bookmarkKey = row.BookmarkKey
        local existingState = bookmarkedStatesByKey[bookmarkKey]
        if existingState then return existingState end

        local bookmarkedState =
            Bookmarks.GetState(outerScope, bookmarkKey)
        bookmarkedStatesByKey[bookmarkKey] = bookmarkedState
        return bookmarkedState
    end

    local rowsToFilter: Fusion.UsedAs<{ RowDescriptor }> =
        if bookmarkable or props.Presorted
        then sourceRowsState
        else SortRows(scope, sourceRowsState, getBookmarkState)

    local bookmarksOnlyState =
        GetBookmarksOnlyState(outerScope)
    local filterState = GetFilterState(outerScope)

    -- Filter preparation is proportional to the full category size. Delay it
    -- until text filtering is requested. Keep only the current dynamic
    -- preparation so tag/attribute refreshes cannot retain every historical
    -- row list. StableKeys preserves the previous contract of one preparation
    -- even when sorting changes identity.
    local lastFilterRows: { RowDescriptor }? = nil
    local lastRowFilter: RowFilter? = nil
    local stableRowFilter: RowFilter? = nil
    local function getRowFilter(rows: { RowDescriptor }): RowFilter
        if props.StableKeys and stableRowFilter then
            return stableRowFilter
        end

        if rows == lastFilterRows and lastRowFilter then
            return lastRowFilter
        end

        local rowFilter =
            (CreateItemFilter :: any)(rows) :: RowFilter
        lastFilterRows = rows
        lastRowFilter = rowFilter
        if props.StableKeys then stableRowFilter = rowFilter end
        return rowFilter
    end

    local filteredRows =
        FilterRows(
            scope,
            filterState,
            bookmarksOnlyState,
            bookmarkable,
            rowsToFilter,
            getBookmarkState,
            getRowFilter
        )
    local displayRows: Fusion.UsedAs<{ RowDescriptor }> =
        if bookmarkable
        then SortRows(scope, filteredRows, getBookmarkState)
        else filteredRows

    -- Hydrated rows deliberately outlive any VirtualMapScrollable detail
    -- scope. Filtering, bookmark reordering, and shape replacement therefore
    -- reuse both the Map.Item and all of its observation resources.
    local hydratedRowsByRow: {
        [RowDescriptor]: HydratedRow
    } = {}
    local function hydrateRow(row: RowDescriptor): Item
        local existingRow = hydratedRowsByRow[row]
        if existingRow then return existingRow.Item end

        local hydrationScope = InnerScope(scope)
        local item = row.Hydrate(hydrationScope)
        local bookmarkedState = getBookmarkState(row)
        local hydratedItem =
            if bookmarkedState
            then DecorateBookmarkItem(
                outerScope,
                row,
                item,
                bookmarkedState
            )
            else item

        hydratedRowsByRow[row] = {
            Item = hydratedItem,
            Scope = hydrationScope
        }
        return hydratedItem
    end

    -- Dynamic categories replace their descriptor objects when their source
    -- changes. Retire hydrated rows which no longer belong to the source after
    -- the coalesced map commit has had time to unmount the previous detail
    -- window. Filtering alone does not evict rows, so scrolling/filter toggles
    -- continue to reuse their hydration.
    local currentSourceRows: {
        [RowDescriptor]: boolean
    } = {}
    local hydrationCleanupRevision = 0
    local categoryAlive = true

    local function indexCurrentSourceRows()
        local nextSourceRows: {
            [RowDescriptor]: boolean
        } = {}
        for _, row in Peek<<{ RowDescriptor }>>(sourceRowsState) do
            nextSourceRows[row] = true
        end
        currentSourceRows = nextSourceRows
    end

    local function queueStaleHydrationCleanup()
        indexCurrentSourceRows()
        hydrationCleanupRevision += 1
        local queuedRevision = hydrationCleanupRevision

        task.defer(function()
            task.defer(function()
                if not categoryAlive
                    or hydrationCleanupRevision ~= queuedRevision
                then
                    return
                end

                for row, hydratedRow in hydratedRowsByRow do
                    if currentSourceRows[row] then continue end

                    hydratedRowsByRow[row] = nil
                    Fusion.doCleanup(hydratedRow.Scope)
                end
            end)
        end)
    end

    indexCurrentSourceRows()
    Observer(scope, sourceRowsState):onChange(
        queueStaleHydrationCleanup
    )
    table.insert(scope, function()
        categoryAlive = false
        hydrationCleanupRevision += 1
    end)

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
    local previousDisplayRows: { RowDescriptor }? = nil

    local function refreshCategory()
        local usedDisplayRows =
            Peek<<{ RowDescriptor }>>(displayRows)
        local usedFilter = Peek<<string?>>(filterState)
        local hasActiveFilter =
            Peek<<boolean>>(bookmarksOnlyState)
            or HasTextFilter(usedFilter)
        local visible = not (
            #usedDisplayRows == 0 and
            (not props.EmptyText or hasActiveFilter)
        )

        if visible then
            if not categoryVisible
                or usedDisplayRows ~= previousDisplayRows
            then
                local shape = table.clone(shapeTemplate)
                shape.RowCount = #usedDisplayRows
                local detailRows = usedDisplayRows

                categoryState:set({
                    Shape = shape,
                    Detail = function(
                        _detailScope: Fusion.Scope,
                        rowIdx: number
                    ): Item
                        local row = assert(
                            detailRows[rowIdx],
                            `Missing {name} detail for row {rowIdx}.`
                        )
                        return hydrateRow(row)
                    end
                })
            end
        elseif categoryVisible then
            categoryState:set(nil)
        end

        categoryVisible = visible
        previousDisplayRows = usedDisplayRows
    end

    -- Empty sorted lists can keep their identity across filter changes.
    -- Observe all inputs that determine category visibility.
    Observer(scope, displayRows):onChange(refreshCategory)
    Observer(scope, bookmarksOnlyState):onChange(refreshCategory)
    Observer(scope, filterState):onChange(refreshCategory)
    refreshCategory()

    return categoryState
end
