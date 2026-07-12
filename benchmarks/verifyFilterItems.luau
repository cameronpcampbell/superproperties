--!strict

local CreateItemFilter =
    require("../src/blocks/properties/maps/category/filterItems")

type Item = { Key: string, Value: any }
type ItemFilter = (query: string?) -> { Item }

local function CreateFilter(items: { Item }): ItemFilter
    return CreateItemFilter(items)
end

local HashModulus = 2_147_483_647
local hash = 5381
local comparisonCount = 0

local function HashNumber(value: number)
    hash = (hash * 65_599 + value) % HashModulus
end

local function HashString(value: string)
    HashNumber(#value)
    for idx = 1, #value do
        HashNumber(value:byte(idx))
    end
end

local function Record(filter: ItemFilter, query: string?)
    local result = filter(query)
    comparisonCount += 1

    HashString(query or "<nil>")
    HashNumber(#result)

    for _, item in result do
        HashNumber(item.Value :: number)
        HashString(item.Key)
    end
end

local curatedItems = {
    { Key = "AbsolutePosition", Value = 1 },
    { Key = "absolutePosition", Value = 2 },
    { Key = "Auto Position", Value = 3 },
    { Key = "Auto-Position", Value = 4 },
    { Key = "XMLHttpRequest", Value = 5 },
    { Key = "X_Manual", Value = 6 },
    { Key = "Transparency", Value = 7 },
    { Key = "TextTransparency", Value = 8 },
    { Key = "TextTransparency", Value = 9 },
    { Key = " leading\tWhitespace ", Value = 10 },
    { Key = "ÅngströmValue", Value = 11 },
    { Key = "", Value = 12 }
}

local curatedQueries = {
    "", " ", "a", "ap", "abs", "AP", "xp", "xml", "xhr", "position",
    "trnsp", "tt", "ttr", "_m", "ång", "zzzz", "  text  transparency "
}

local curatedFilter = CreateFilter(curatedItems)
Record(curatedFilter, nil)
for _, query in curatedQueries do
    Record(curatedFilter, query)
end

local mutableItems = {
    { Key = "BeforeMutation", Value = 101 },
    { Key = "AfterMutation", Value = 102 }
}
local mutableFilter = CreateFilter(mutableItems)
Record(mutableFilter, "before")
mutableItems[1].Key = "CompletelyDifferent"
Record(mutableFilter, "before")
Record(mutableFilter, "different")

math.randomseed(0x5EED)

local alphabet =
    "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_- .\t\n\r"

local function RandomString(maxLength: number): string
    local length = math.random(0, maxLength)
    local characters = table.create(length) :: { string }

    for idx = 1, length do
        local alphabetIdx = math.random(1, #alphabet)
        characters[idx] = alphabet:sub(alphabetIdx, alphabetIdx)
    end

    return table.concat(characters)
end

for datasetIdx = 1, 150 do
    local itemCount = math.random(0, 80)
    local items = table.create(itemCount) :: { Item }

    for itemIdx = 1, itemCount do
        items[itemIdx] = {
            Key = RandomString(32),
            Value = datasetIdx * 100 + itemIdx
        }
    end

    local filter = CreateFilter(items)
    Record(filter, nil)

    for _ = 2, 12 do
        Record(filter, RandomString(10))
    end
end

assert(comparisonCount == 1_821, `unexpected comparison count: {comparisonCount}`)
assert(hash == 1_396_902_059, `filterItems result hash changed: {hash}`)
print(`filterItems verification: comparisons={comparisonCount} hash={hash}`)
