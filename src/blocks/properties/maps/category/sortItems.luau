--!strict

export type Item = {
    Key: string,
    BookmarkKey: string?
}

type GetBookmarked = (item: any) -> boolean

local function HasSameItemOrder(
    previousItems: { any },
    nextItems: { any }
): boolean
    if #previousItems ~= #nextItems then return false end

    for itemIdx, item in nextItems do
        if previousItems[itemIdx] ~= item then return false end
    end

    return true
end

return function(
    items: { any },
    getBookmarked: GetBookmarked,
    previousItems: { any }?
): { any }
    local sortedItems = table.clone(items)

    table.sort(sortedItems, function(
        leftValue: any,
        rightValue: any
    ): boolean
        local leftItem = leftValue :: Item
        local rightItem = rightValue :: Item
        local leftBookmarked = getBookmarked(leftItem)
        local rightBookmarked = getBookmarked(rightItem)

        if leftBookmarked ~= rightBookmarked then
            return leftBookmarked
        end
        if leftItem.Key ~= rightItem.Key then
            return leftItem.Key < rightItem.Key
        end

        local leftBookmarkKey = leftItem.BookmarkKey or ""
        local rightBookmarkKey = rightItem.BookmarkKey or ""
        return leftBookmarkKey < rightBookmarkKey
    end)

    -- Fusion compares frozen tables by identity. Reusing this result prevents
    -- Mosaic from remounting rows when a bookmark toggle keeps the same order.
    if previousItems
        and HasSameItemOrder(previousItems, sortedItems)
    then
        return previousItems
    end

    return table.freeze(sortedItems)
end
