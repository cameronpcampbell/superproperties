--!strict

local VirtualMapScrollableMath = require("./math")

local ShouldRefreshBufferedWindow =
    VirtualMapScrollableMath.ShouldRefreshBufferedWindow
local GetStableLayoutOrderIndices =
    VirtualMapScrollableMath.GetStableLayoutOrderIndices
local FindVisibleMapRange =
    VirtualMapScrollableMath.FindVisibleMapRange

local function AssertEqual(actual: number, expected: number, label: string)
    assert(
        actual == expected,
        `{label}: expected {expected}, got {actual}`
    )
end

assert(
    ShouldRefreshBufferedWindow(nil, nil, 100, 200, 20),
    "a window must be published when both rendered bounds are missing"
)
assert(
    ShouldRefreshBufferedWindow(nil, 220, 100, 200, 20),
    "a window must be published when the rendered top is missing"
)
assert(
    ShouldRefreshBufferedWindow(80, nil, 100, 200, 20),
    "a window must be published when the rendered bottom is missing"
)
assert(
    not ShouldRefreshBufferedWindow(50, 250, 100, 200, 20),
    "a viewport with buffer on both sides must reuse the rendered window"
)
assert(
    not ShouldRefreshBufferedWindow(80, 220, 100, 200, 20),
    "buffer exactly at the minimum must reuse the rendered window"
)
assert(
    ShouldRefreshBufferedWindow(81, 250, 100, 200, 20),
    "crossing the top buffer threshold must refresh"
)
assert(
    ShouldRefreshBufferedWindow(50, 219, 100, 200, 20),
    "crossing the bottom buffer threshold must refresh"
)
assert(
    ShouldRefreshBufferedWindow(80, 220, 10, 110, 20),
    "a jump above the rendered window must refresh"
)
assert(
    ShouldRefreshBufferedWindow(80, 220, 190, 290, 20),
    "a jump below the rendered window must refresh"
)

local renderedTop = 80
local renderedBottom = 220

assert(
    not ShouldRefreshBufferedWindow(
        renderedTop,
        renderedBottom,
        100,
        200,
        20
    ),
    "the initial viewport must reuse a sufficiently buffered window"
)
assert(
    ShouldRefreshBufferedWindow(
        renderedTop,
        renderedBottom,
        101,
        201,
        20
    ),
    "scrolling forward past the bottom threshold must refresh"
)
assert(
    ShouldRefreshBufferedWindow(
        renderedTop,
        renderedBottom,
        79,
        179,
        20
    ),
    "reversing above the top threshold must refresh"
)
assert(
    not ShouldRefreshBufferedWindow(100, 200, 100, 200, 0),
    "a zero minimum buffer must reuse an exactly matching window"
)
assert(
    ShouldRefreshBufferedWindow(100, 200, 101, 201, 0),
    "a zero minimum buffer must refresh after leaving the bottom edge"
)
assert(
    ShouldRefreshBufferedWindow(100, 200, 99, 199, 0),
    "a zero minimum buffer must refresh after leaving the top edge"
)
assert(
    not ShouldRefreshBufferedWindow(100, 200, 100, 200, -10),
    "a negative minimum buffer must be clamped to zero"
)
assert(
    ShouldRefreshBufferedWindow(100, 200, 201, 301, -10),
    "a negative minimum buffer must still detect a viewport jump"
)

local bufferedWindowTop: number? = nil
local bufferedWindowBottom: number? = nil
local bufferedRefreshCount = 0

for canvasY = 0, 99 do
    local viewportTop = canvasY
    local viewportBottom = canvasY + 100

    if not ShouldRefreshBufferedWindow(
        bufferedWindowTop,
        bufferedWindowBottom,
        viewportTop,
        viewportBottom,
        20
    ) then
        continue
    end

    bufferedWindowTop = viewportTop - 60
    bufferedWindowBottom = viewportBottom + 60
    bufferedRefreshCount += 1
end

AssertEqual(
    bufferedRefreshCount,
    3,
    "a six-row window with a two-row minimum should replenish sparsely"
)

local stableOrderIndices =
    GetStableLayoutOrderIndices({ 3, 1, 1, 2, 1 })
local expectedStableOrderIndices = { 2, 3, 5, 4, 1 }

for sortedIndex, sourceIndex in expectedStableOrderIndices do
    AssertEqual(
        stableOrderIndices[sortedIndex],
        sourceIndex,
        `stable layout order index {sortedIndex}`
    )
end

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
