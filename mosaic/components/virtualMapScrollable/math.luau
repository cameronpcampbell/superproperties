--!strict

-- Pure scheduling and map-bound helpers for VirtualMapScrollable.

export type GetMapBound = (mapIdx: number) -> number

local function ShouldRefreshVirtualWindow(
    lastRefreshY: number?,
    currentY: number,
    threshold: number
): boolean
    if lastRefreshY == nil then return true end

    return math.abs(currentY - lastRefreshY) >= math.max(threshold, 0)
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
    ShouldRefreshVirtualWindow = ShouldRefreshVirtualWindow,
    FindVisibleMapRange = FindVisibleMapRange
}
