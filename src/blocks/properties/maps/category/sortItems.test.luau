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

assert(sortedItems[1].BookmarkKey == "Data/OwnerA/Beta")
assert(sortedItems[2].BookmarkKey == "Data/OwnerB/Beta")
assert(sortedItems[3].Key == "Alpha")
assert(sortedItems[4].Key == "Zeta")

-- The helper must not mutate the source list.
assert(items[1].Key == "Zeta")

items[1].Bookmarked = true
sortedItems = SortItems(items, GetBookmarked)

assert(sortedItems[1].Key == "Beta")
assert(sortedItems[2].Key == "Beta")
assert(sortedItems[3].Key == "Zeta")
assert(sortedItems[4].Key == "Alpha")

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

print("bookmark sorting verification passed")
