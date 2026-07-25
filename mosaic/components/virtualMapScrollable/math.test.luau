--!strict

local VirtualMapScrollableMath = require("./math")

local ShouldRefreshVirtualWindow =
    VirtualMapScrollableMath.ShouldRefreshVirtualWindow
local FindVisibleMapRange =
    VirtualMapScrollableMath.FindVisibleMapRange

local function AssertEqual(actual: number, expected: number, label: string)
    assert(
        actual == expected,
        `{label}: expected {expected}, got {actual}`
    )
end

assert(
    ShouldRefreshVirtualWindow(nil, 20, 10),
    "the first virtual window must always be published"
)
assert(
    not ShouldRefreshVirtualWindow(20, 29, 10),
    "movement below the threshold must be ignored"
)
assert(
    ShouldRefreshVirtualWindow(20, 30, 10),
    "movement at the threshold must refresh"
)
assert(
    ShouldRefreshVirtualWindow(20, 10, 10),
    "the threshold must work in both directions"
)
assert(
    ShouldRefreshVirtualWindow(20, 20, 0),
    "zero overdraw must disable scroll throttling"
)

local lastRefreshY: number? = nil
local refreshCount = 0

for canvasY = 0, 99 do
    if not ShouldRefreshVirtualWindow(lastRefreshY, canvasY, 10) then
        continue
    end

    lastRefreshY = canvasY
    refreshCount += 1
end

AssertEqual(
    refreshCount,
    10,
    "one-pixel scroll events should refresh once per threshold"
)

local mapTops = { 0, 15, 40, 75 }
local mapBottoms = { 10, 35, 70, 100 }

local function GetMapTop(mapIdx: number): number
    return mapTops[mapIdx]
end

local function GetMapBottom(mapIdx: number): number
    return mapBottoms[mapIdx]
end

local function AssertRange(
    viewportTop: number,
    viewportBottom: number,
    expectedFirst: number,
    expectedLast: number,
    label: string
)
    local firstMap, lastMap = FindVisibleMapRange(
        #mapTops,
        GetMapTop,
        GetMapBottom,
        viewportTop,
        viewportBottom
    )

    AssertEqual(firstMap, expectedFirst, `{label} first map`)
    AssertEqual(lastMap, expectedLast, `{label} last map`)
end

AssertRange(-10, 5, 1, 1, "viewport before the first map")
AssertRange(0, 10, 1, 1, "exact first map bounds")
AssertRange(10, 15, 1, 0, "gap between maps")
AssertRange(10, 16, 2, 2, "partial second map")
AssertRange(30, 80, 2, 4, "multiple intersecting maps")
AssertRange(100, 120, 1, 0, "viewport after the last map")
AssertRange(0, 100, 1, 4, "all maps")

local emptyFirst, emptyLast = FindVisibleMapRange(
    0,
    GetMapTop,
    GetMapBottom,
    0,
    100
)
AssertEqual(emptyFirst, 1, "empty map list first map")
AssertEqual(emptyLast, 0, "empty map list last map")

local boundLookupCount = 0

local function GetLargeMapTop(mapIdx: number): number
    boundLookupCount += 1
    return (mapIdx - 1) * 12
end

local function GetLargeMapBottom(mapIdx: number): number
    boundLookupCount += 1
    return (mapIdx - 1) * 12 + 10
end

local largeFirst, largeLast = FindVisibleMapRange(
    1024,
    GetLargeMapTop,
    GetLargeMapBottom,
    6000,
    6100
)
AssertEqual(largeFirst, 501, "large map list first map")
AssertEqual(largeLast, 509, "large map list last map")
assert(
    boundLookupCount <= 22,
    `large map lookup should be logarithmic, got {boundLookupCount} reads`
)

print("virtualMapScrollableMath verification passed")
