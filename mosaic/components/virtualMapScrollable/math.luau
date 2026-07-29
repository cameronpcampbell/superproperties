--!strict

-- Pure scheduling and map-bound helpers for VirtualMapScrollable.

type GetMapBound = (mapIdx: number) -> number

local function ShouldRefreshBufferedWindow(
    renderedTop: number?,
    renderedBottom: number?,
    viewportTop: number,
    viewportBottom: number,
    minimumBuffer: number
): boolean
    if renderedTop == nil or renderedBottom == nil then
        return true
    end

    local clampedMinimumBuffer = math.max(minimumBuffer, 0)
    local topBuffer = viewportTop - renderedTop
    local bottomBuffer = renderedBottom - viewportBottom

    return topBuffer < clampedMinimumBuffer
        or bottomBuffer < clampedMinimumBuffer
end

local function GetStableLayoutOrderIndices(
    layoutOrders: { number }
): { number }
    local indices = table.create(#layoutOrders) :: { number }

    for sourceIndex in layoutOrders do
        indices[sourceIndex] = sourceIndex
    end

    table.sort(indices, function(a: number, b: number): boolean
        local aOrder = layoutOrders[a]
        local bOrder = layoutOrders[b]

        if aOrder == bOrder then return a < b end
        return aOrder < bOrder
    end)

    return indices
end

local function FindVisibleMapRange(
    mapCount: number,
    getMapTop: GetMapBound,
    getMapBottom: GetMapBound,
    viewportTop: number,
    viewportBottom: number
): (number, number)
    if mapCount <= 0 or viewportTop >= viewportBottom then
        return 1, 0
    end

    -- Map bounds are ordered and non-overlapping. Find the first map whose
    -- bottom extends beyond the viewport's top edge.
    local low = 1
    local high = mapCount + 1

    while low < high do
        local middle = (low + high) // 2

        if getMapBottom(middle) > viewportTop then
            high = middle
        else
            low = middle + 1
        end
    end

    local firstMap = low

    -- Find the first map beginning at or beyond the viewport's bottom edge.
    low = 1
    high = mapCount + 1

    while low < high do
        local middle = (low + high) // 2

        if getMapTop(middle) >= viewportBottom then
            high = middle
        else
            low = middle + 1
        end
    end

    local lastMap = low - 1

    if firstMap > mapCount or firstMap > lastMap then
        return 1, 0
    end

    return firstMap, lastMap
end

return {
    ShouldRefreshBufferedWindow = ShouldRefreshBufferedWindow,
    GetStableLayoutOrderIndices = GetStableLayoutOrderIndices,
    FindVisibleMapRange = FindVisibleMapRange
}
