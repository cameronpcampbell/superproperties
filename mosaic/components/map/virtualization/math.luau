--!strict

-- Pure row geometry helpers for the virtualized map module.

export type RowGeometry = {
    Tops: { number },
    Bottoms: { number },
    SpacerHeights: { number },
    TotalHeight: number
}

export type RootRange = {
    First: number,
    Last: number
}

local function BuildRowGeometry(
    rowHeights: { number },
    contentPadding: number,
    rowGap: number
): RowGeometry
    local rowCount = #rowHeights
    local tops = table.create(rowCount) :: { number }
    local bottoms = table.create(rowCount) :: { number }
    local spacerHeights = table.create(rowCount) :: { number }
    local rowTop = contentPadding

    for rowIdx, rowHeight in rowHeights do
        tops[rowIdx] = rowTop
        bottoms[rowIdx] = rowTop + rowHeight
        spacerHeights[rowIdx] =
            if rowIdx == 1
            then 0
            else rowTop - contentPadding - rowGap

        rowTop += rowHeight + rowGap
    end

    return {
        Tops = tops,
        Bottoms = bottoms,
        SpacerHeights = spacerHeights,
        TotalHeight = if rowCount == 0 then contentPadding else rowTop
    }
end

local function FindFirstGreater(values: { number }, target: number): number
    local low = 1
    local high = #values + 1

    while low < high do
        local middle = (low + high) // 2

        if values[middle] > target then
            high = middle
        else
            low = middle + 1
        end
    end

    return low
end

local function FindFirstGreaterOrEqual(
    values: { number },
    target: number
): number
    local low = 1
    local high = #values + 1

    while low < high do
        local middle = (low + high) // 2

        if values[middle] >= target then
            high = middle
        else
            low = middle + 1
        end
    end

    return low
end

local function FindVisibleRange(
    geometry: RowGeometry,
    viewportTop: number,
    viewportBottom: number
): (number, number)
    local firstRow = FindFirstGreater(geometry.Bottoms, viewportTop)
    local lastRow = FindFirstGreaterOrEqual(
        geometry.Tops,
        viewportBottom
    ) - 1

    if firstRow > #geometry.Tops
        or lastRow < 1
        or firstRow > lastRow
    then
        return 1, 0
    end

    return firstRow, lastRow
end

local function CalculateTopSpacerHeight(
    geometry: RowGeometry,
    firstVisibleRow: number,
    firstRowRetained: boolean,
    rowGap: number
): number
    if firstVisibleRow <= 1 then return 0 end

    local spacerHeight =
        geometry.SpacerHeights[firstVisibleRow] or 0

    if firstRowRetained then
        local firstRowTop = geometry.Tops[1]
        local firstRowBottom = geometry.Bottoms[1]

        if firstRowTop and firstRowBottom then
            spacerHeight -=
                firstRowBottom - firstRowTop + rowGap
        end
    end

    return math.max(spacerHeight, 0)
end

local function MergeRootRanges(
    rowCount: number,
    ranges: { RootRange }
): { RootRange }
    local clampedRowCount = math.max(rowCount, 0)
    local sortedRanges = {} :: { RootRange }

    for _, range in ranges do
        local firstRow = math.max(range.First, 1)
        local lastRow = math.min(range.Last, clampedRowCount)

        if firstRow <= lastRow then
            table.insert(sortedRanges, {
                First = firstRow,
                Last = lastRow
            })
        end
    end

    table.sort(sortedRanges, function(a: RootRange, b: RootRange): boolean
        if a.First == b.First then return a.Last < b.Last end
        return a.First < b.First
    end)

    local mergedRanges = {} :: { RootRange }

    for _, range in sortedRanges do
        local previousRange = mergedRanges[#mergedRanges]

        if previousRange
            and range.First <= previousRange.Last + 1
        then
            previousRange.Last = math.max(
                previousRange.Last,
                range.Last
            )
        else
            table.insert(mergedRanges, {
                First = range.First,
                Last = range.Last
            })
        end
    end

    return mergedRanges
end

-- Only omitted rows before and between rendered ranges need spacers. The map
-- owns its full numeric height, so an omitted suffix can remain empty.
local function FindRootRangeGaps(
    renderedRanges: { RootRange }
): { RootRange }
    local gaps = {} :: { RootRange }
    local previousLastRow = 0

    for _, range in renderedRanges do
        local firstSkippedRow = previousLastRow + 1
        local lastSkippedRow = range.First - 1

        if firstSkippedRow <= lastSkippedRow then
            table.insert(gaps, {
                First = firstSkippedRow,
                Last = lastSkippedRow
            })
        end

        previousLastRow = math.max(previousLastRow, range.Last)
    end

    return gaps
end

local function CalculateGapSpacerHeight(
    geometry: RowGeometry,
    firstSkippedRow: number,
    lastSkippedRow: number
): number
    if firstSkippedRow > lastSkippedRow then return 0 end

    local gapTop = geometry.Tops[firstSkippedRow]
    local gapBottom = geometry.Bottoms[lastSkippedRow]

    if gapTop == nil or gapBottom == nil then return 0 end
    return math.max(gapBottom - gapTop, 0)
end

local function RootRangeToItemRange(
    firstRootRow: number,
    lastRootRow: number,
    hasHeader: boolean,
    itemCount: number
): (number, number)
    local headerOffset = if hasHeader then 1 else 0
    local firstItem = math.max(firstRootRow - headerOffset, 1)
    local lastItem = math.min(
        lastRootRow - headerOffset,
        itemCount
    )

    if itemCount <= 0 or firstItem > lastItem then
        return 1, 0
    end

    return firstItem, lastItem
end

return {
    BuildRowGeometry = BuildRowGeometry,
    FindVisibleRange = FindVisibleRange,
    CalculateTopSpacerHeight = CalculateTopSpacerHeight,
    MergeRootRanges = MergeRootRanges,
    FindRootRangeGaps = FindRootRangeGaps,
    CalculateGapSpacerHeight = CalculateGapSpacerHeight,
    RootRangeToItemRange = RootRangeToItemRange
}
