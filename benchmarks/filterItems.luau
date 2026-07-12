--!strict

local FilterItems = require("../src/blocks/properties/maps/category/filterItems")

type Item = { Key: string, Value: any }
type Filter = (items: { Item }, query: string?) -> { Item }

local Roots = {
    "Absolute", "Active", "Automatic", "Background", "Camera", "Content",
    "Current", "Display", "Enabled", "Font", "Image", "Layout", "Light",
    "Maximum", "Minimum", "Navigation", "Position", "Primary", "Render",
    "Rotation", "Selection", "Text", "Transparency", "Visible"
}

local Suffixes = {
    "Color", "Direction", "Enabled", "Mode", "Offset", "Position", "Size",
    "Speed", "Text", "Transparency", "Value", "XAlignment", "ZIndex"
}

local Qualifiers = {
    "", "Constraint", "Offset", "Scale", "Target", "World"
}

local Queries = {
    "abs",      -- prefix
    "ac",       -- boundary initials
    "position", -- substring
    "trnsp",    -- subsequence
    "text",     -- common prefix/substring
    "xm",       -- short boundary query
    "p",        -- short boundary substring
    "zzzz",     -- miss
    "automaticmode", -- exact for some generated keys
    "  ReN der " -- normalization plus subsequence
}

local function BuildItems(count: number): { Item }
    local items = table.create(count) :: { Item }

    for idx = 1, count do
        local root = Roots[(idx - 1) % #Roots + 1]
        local suffix = Suffixes[(idx * 5 - 1) % #Suffixes + 1]
        local qualifier = Qualifiers[(idx * 7 - 1) % #Qualifiers + 1]
        local key = root .. qualifier .. suffix

        if idx % 11 == 0 then
            key = root .. " " .. qualifier .. suffix
        elseif idx % 17 == 0 then
            key = root .. "-" .. qualifier .. suffix
        end

        items[idx] = {
            Key = key,
            Value = idx
        }
    end

    return items
end

local function Consume(filteredItems: { Item }): number
    local count = #filteredItems
    if count == 0 then return 1 end

    return count + #filteredItems[1].Key + #filteredItems[count].Key
end

local function RunWarm(
    filter: Filter,
    itemCount: number,
    iterations: number
): (number, number)
    local items = BuildItems(itemCount)
    local checksum = 0

    -- Prime any candidate cache before measuring repeated filter changes.
    for _, query in Queries do
        checksum += Consume(filter(items, query))
    end

    local startedAt = os.clock()
    for iteration = 1, iterations do
        local query = Queries[(iteration - 1) % #Queries + 1]
        checksum += Consume(filter(items, query))
    end

    return os.clock() - startedAt, checksum
end

local function RunCold(
    filter: Filter,
    itemCount: number,
    iterations: number
): (number, number)
    local itemSets = table.create(iterations) :: { { Item } }
    for iteration = 1, iterations do
        itemSets[iteration] = BuildItems(itemCount)
    end

    local checksum = 0
    local startedAt = os.clock()
    for iteration = 1, iterations do
        local query = Queries[(iteration - 1) % #Queries + 1]
        checksum += Consume(filter(itemSets[iteration], query))
    end

    return os.clock() - startedAt, checksum
end

local function Median(values: { number }): number
    table.sort(values)
    return values[math.ceil(#values / 2)]
end

local function Benchmark(
    name: string,
    runner: (Filter, number, number) -> (number, number),
    itemCount: number,
    iterations: number
)
    local samples = table.create(9) :: { number }
    local checksum = 0

    -- Warm the VM and code paths; RunCold still receives fresh item objects.
    runner(FilterItems, itemCount, math.max(2, math.floor(iterations / 10)))

    for sampleIdx = 1, 9 do
        local elapsed, sampleChecksum =
            runner(FilterItems, itemCount, iterations)
        samples[sampleIdx] = elapsed
        checksum += sampleChecksum
    end

    local median = Median(samples)
    print(string.format(
        "%-10s %8.3f ms  %8.3f us/call  checksum=%d",
        name,
        median * 1_000,
        median * 1_000_000 / iterations,
        checksum
    ))
end

print("filterItems benchmark (median of 9 samples)")
Benchmark("warm-64", RunWarm, 64, 1_000)
Benchmark("warm-512", RunWarm, 512, 150)
Benchmark("cold-64", RunCold, 64, 250)
Benchmark("cold-512", RunCold, 512, 30)
