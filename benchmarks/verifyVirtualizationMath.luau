--!strict

local VirtualizationMath =
    require("../mosaic/components/map/virtualization/math")

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
