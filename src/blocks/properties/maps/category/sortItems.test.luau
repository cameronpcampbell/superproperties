--!strict

local SortItems = require("./sortItems")

type Item = {
    Key: string,
    BookmarkKey: string?,
    Bookmarked: boolean
}

local function GetBookmarked(item: Item): boolean
    return item.Bookmarked
end

local items: { Item } = {
    {
        Key = "Zeta",
        BookmarkKey = "Data/Owner/Zeta",
        Bookmarked = false
    },
    {
        Key = "Beta",
        BookmarkKey = "Data/OwnerB/Beta",
        Bookmarked = true
    },
    {
        Key = "Alpha",
        BookmarkKey = "Data/Owner/Alpha",
        Bookmarked = false
    },
    {
        Key = "Beta",
        BookmarkKey = "Data/OwnerA/Beta",
        Bookmarked = true
    }
}

local sortedItems = SortItems(items, GetBookmarked)

assert(table.isfrozen(sortedItems))
assert(sortedItems[1].BookmarkKey == "Data/OwnerA/Beta")
assert(sortedItems[2].BookmarkKey == "Data/OwnerB/Beta")
assert(sortedItems[3].Key == "Alpha")
assert(sortedItems[4].Key == "Zeta")

-- The helper must not mutate the source list.
assert(items[1].Key == "Zeta")

items[1].Bookmarked = true
local reorderedItems = SortItems(items, GetBookmarked, sortedItems)

assert(reorderedItems ~= sortedItems)
assert(reorderedItems[1].Key == "Beta")
assert(reorderedItems[2].Key == "Beta")
assert(reorderedItems[3].Key == "Zeta")
assert(reorderedItems[4].Key == "Alpha")

-- Changing bookmark state without changing position preserves list identity.
local singleItem: Item = {
    Key = "Only",
    BookmarkKey = "Data/Owner/Only",
    Bookmarked = false
}
local singleItems = { singleItem }
local sortedSingleItems = SortItems(singleItems, GetBookmarked)

singleItem.Bookmarked = true
local unchangedSingleItems =
    SortItems(singleItems, GetBookmarked, sortedSingleItems)

assert(unchangedSingleItems == sortedSingleItems)

-- Replacing an item at the same position must still refresh the map row.
local replacementItems = table.clone(items)
replacementItems[3] = table.clone(items[3])
local replacedItems =
    SortItems(replacementItems, GetBookmarked, reorderedItems)

assert(replacedItems ~= reorderedItems)

-- Search passes its matching subset through the same final display sort.
local matchingItems: { Item } = {
    {
        Key = "AlphaMatch",
        BookmarkKey = "Data/Owner/AlphaMatch",
        Bookmarked = false
    },
    {
        Key = "ZetaMatch",
        BookmarkKey = "Data/Owner/ZetaMatch",
        Bookmarked = true
    }
}
local sortedMatches = SortItems(matchingItems, GetBookmarked)

assert(sortedMatches[1].Key == "ZetaMatch")
assert(sortedMatches[2].Key == "AlphaMatch")

matchingItems[1].Bookmarked = true
matchingItems[2].Bookmarked = false
local reorderedMatches =
    SortItems(matchingItems, GetBookmarked, sortedMatches)

assert(reorderedMatches ~= sortedMatches)
assert(reorderedMatches[1].Key == "AlphaMatch")
assert(reorderedMatches[2].Key == "ZetaMatch")

matchingItems[1].Bookmarked = false
local unchangedMatches =
    SortItems(matchingItems, GetBookmarked, reorderedMatches)

assert(unchangedMatches == reorderedMatches)

print("bookmark sorting verification passed")
