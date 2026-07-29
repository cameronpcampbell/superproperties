--!strict

local VirtualizationMath =
    require("./math")

local function AssertEqual(actual: number, expected: number, label: string)
    assert(
        actual == expected,
        `{label}: expected {expected}, got {actual}`
    )
end

local geometry = VirtualizationMath.BuildRowGeometry({ 10, 20, 30 }, 1, 1)
AssertEqual(geometry.Tops[1], 1, "first top")
AssertEqual(geometry.Tops[2], 12, "second top")
AssertEqual(geometry.Tops[3], 33, "third top")
AssertEqual(geometry.Bottoms[3], 63, "last bottom")
AssertEqual(geometry.SpacerHeights[1], 0, "first spacer")
AssertEqual(geometry.SpacerHeights[2], 10, "second spacer")
AssertEqual(geometry.SpacerHeights[3], 31, "third spacer")
AssertEqual(geometry.TotalHeight, 64, "total height")
AssertEqual(
    VirtualizationMath.CalculateTopSpacerHeight(
        geometry,
        3,
        false,
        1
    ),
    31,
    "ordinary top spacer"
)
AssertEqual(
    VirtualizationMath.CalculateTopSpacerHeight(
        geometry,
        2,
        true,
        1
    ),
    0,
    "retained first row adjacent spacer"
)
AssertEqual(
    VirtualizationMath.CalculateTopSpacerHeight(
        geometry,
        3,
        true,
        1
    ),
    20,
    "retained first row top spacer"
)

local mergedRanges = VirtualizationMath.MergeRootRanges(200, {
    { First = 160, Last = 175 },
    { First = 5, Last = 5 },
    { First = 1, Last = 1 },
    { First = 174, Last = 180 }
})

AssertEqual(#mergedRanges, 3, "disjoint merged range count")
AssertEqual(mergedRanges[1].First, 1, "pinned range first")
AssertEqual(mergedRanges[1].Last, 1, "pinned range last")
AssertEqual(mergedRanges[2].First, 5, "focused range first")
AssertEqual(mergedRanges[2].Last, 5, "focused range last")
AssertEqual(mergedRanges[3].First, 160, "visible range first")
AssertEqual(mergedRanges[3].Last, 180, "visible range last")
AssertEqual(
    #VirtualizationMath.MergeRootRanges(0, {
        { First = 1, Last = 5 }
    }),
    0,
    "empty row set drops ranges"
)

local adjacentRanges = VirtualizationMath.MergeRootRanges(10, {
    { First = -5, Last = 2 },
    { First = 3, Last = 4 },
    { First = 9, Last = 20 },
    { First = 8, Last = 8 },
    { First = 7, Last = 6 }
})

AssertEqual(#adjacentRanges, 2, "clamped adjacent range count")
AssertEqual(adjacentRanges[1].First, 1, "clamped first range start")
AssertEqual(adjacentRanges[1].Last, 4, "adjacent ranges merge")
AssertEqual(adjacentRanges[2].First, 8, "clamped second range start")
AssertEqual(adjacentRanges[2].Last, 10, "clamped second range end")

local rangeGaps = VirtualizationMath.FindRootRangeGaps({
    { First = 1, Last = 1 },
    { First = 5, Last = 5 },
    { First = 8, Last = 10 }
})

AssertEqual(#rangeGaps, 2, "sparse range gap count")
AssertEqual(rangeGaps[1].First, 2, "first internal gap start")
AssertEqual(rangeGaps[1].Last, 4, "first internal gap end")
AssertEqual(rangeGaps[2].First, 6, "second internal gap start")
AssertEqual(rangeGaps[2].Last, 7, "second internal gap end")

local prefixGaps = VirtualizationMath.FindRootRangeGaps({
    { First = 3, Last = 3 }
})

AssertEqual(#prefixGaps, 1, "prefix gap count")
AssertEqual(prefixGaps[1].First, 1, "prefix gap start")
AssertEqual(prefixGaps[1].Last, 2, "prefix gap end")
AssertEqual(
    #VirtualizationMath.FindRootRangeGaps({}),
    0,
    "empty range set has no gaps"
)

AssertEqual(
    VirtualizationMath.CalculateGapSpacerHeight(geometry, 1, 2),
    31,
    "prefix gap spacer height"
)
AssertEqual(
    VirtualizationMath.CalculateGapSpacerHeight(geometry, 2, 2),
    20,
    "single-row gap spacer height"
)
AssertEqual(
    VirtualizationMath.CalculateGapSpacerHeight(geometry, 3, 2),
    0,
    "empty gap spacer height"
)
AssertEqual(
    VirtualizationMath.CalculateGapSpacerHeight(geometry, 2, 8),
    0,
    "out-of-bounds gap spacer height"
)

local function AssertRange(
    viewportTop: number,
    viewportBottom: number,
    expectedFirst: number,
    expectedLast: number
)
    local firstRow, lastRow = VirtualizationMath.FindVisibleRange(
        geometry,
        viewportTop,
        viewportBottom
    )

    AssertEqual(firstRow, expectedFirst, "first visible row")
    AssertEqual(lastRow, expectedLast, "last visible row")
end

AssertRange(0, 1, 1, 0)
AssertRange(1, 11, 1, 1)
AssertRange(11, 12, 1, 0)
AssertRange(12, 32, 2, 2)
AssertRange(0, 100, 1, 3)
AssertRange(63, 100, 1, 0)

local function AssertItemRange(
    firstRootRow: number,
    lastRootRow: number,
    hasHeader: boolean,
    itemCount: number,
    expectedFirst: number,
    expectedLast: number,
    label: string
)
    local firstItem, lastItem =
        VirtualizationMath.RootRangeToItemRange(
            firstRootRow,
            lastRootRow,
            hasHeader,
            itemCount
        )

    AssertEqual(firstItem, expectedFirst, `{label} first item`)
    AssertEqual(lastItem, expectedLast, `{label} last item`)
end

AssertItemRange(1, 4, false, 10, 1, 4, "headerless range")
AssertItemRange(1, 4, true, 10, 1, 3, "range containing header")
AssertItemRange(1, 1, true, 10, 1, 0, "header-only range")
AssertItemRange(4, 8, true, 5, 3, 5, "range clamped to item count")
AssertItemRange(1, 4, false, 0, 1, 0, "empty item range")
AssertItemRange(20, 30, true, 5, 1, 0, "range after all items")

local rowHeights = table.create(512) :: { number }
for rowIdx = 1, 512 do
    rowHeights[rowIdx] = 20 + rowIdx % 7 * 3
end

local largeGeometry = VirtualizationMath.BuildRowGeometry(
    rowHeights,
    1,
    1
)

local function FindVisibleRangeLinear(
    viewportTop: number,
    viewportBottom: number
): (number, number)
    local firstRow, lastRow = 1, 0

    for rowIdx, rowTop in largeGeometry.Tops do
        local rowBottom = largeGeometry.Bottoms[rowIdx]

        if rowBottom > viewportTop and rowTop < viewportBottom then
            if firstRow > lastRow then firstRow = rowIdx end
            lastRow = rowIdx
        end
    end

    return firstRow, lastRow
end

for viewportTop = -100, largeGeometry.TotalHeight + 100, 7 do
    local viewportBottom = viewportTop + 317
    local expectedFirst, expectedLast = FindVisibleRangeLinear(
        viewportTop,
        viewportBottom
    )
    local actualFirst, actualLast = VirtualizationMath.FindVisibleRange(
        largeGeometry,
        viewportTop,
        viewportBottom
    )

    AssertEqual(actualFirst, expectedFirst, "large first visible row")
    AssertEqual(actualLast, expectedLast, "large last visible row")
end

print("virtualizationMath verification passed")
