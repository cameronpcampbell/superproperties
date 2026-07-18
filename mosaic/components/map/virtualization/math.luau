--!strict

-- Pure row geometry helpers for the virtualized map module.

export type RowGeometry = {
    Tops: { number },
    Bottoms: { number },
    SpacerHeights: { number },
    TotalHeight: number
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

return {
    BuildRowGeometry = BuildRowGeometry,
    FindVisibleRange = FindVisibleRange
}
