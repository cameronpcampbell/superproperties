--!strict

export type Item = {
    Key: string,
    BookmarkKey: string?
}

type GetBookmarked = (item: any) -> boolean

return function(
    items: { any },
    getBookmarked: GetBookmarked
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

    return sortedItems
end
