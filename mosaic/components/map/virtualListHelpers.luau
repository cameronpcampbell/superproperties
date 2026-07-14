--!strict

local Packages = script.Parent.Parent.Parent.Parent

local Fusion = require(Packages.fusion)
local Computed = Fusion.Computed

export type VirtualListData = {
    ViewportAbsolutePosition: Fusion.UsedAs<Vector2>,
    ViewportAbsoluteSize: Fusion.UsedAs<Vector2>,
    MapAbsolutePosition: Fusion.UsedAs<Vector2>,
    MapAbsoluteSize: Fusion.UsedAs<Vector2>,
    Overdraw: Fusion.UsedAs<number>
}

local function CalculateMapRowCount(
    itemCount: number,
    hasHeader: boolean,
    hasEmptyText: boolean
): number
    local rowCount = if hasHeader then 1 else 0

    if itemCount > 0 then
        rowCount += itemCount

    elseif hasEmptyText then
        rowCount += 1
    end

    return rowCount
end

local function CalculateMapHeight(rowCount: number, lgHeight: number): number
    -- Each row is inset by the map's one-pixel stroke. The remaining pixels
    -- account for the gaps between rows and the map's outer padding.
    local rowHeight = lgHeight - 2

    return rowHeight * rowCount + rowCount + 1
end

local function ComputeVirtualListOccludesMap(
    scope: Fusion.Scope,
    virtualListData: VirtualListData?
): Fusion.Computed<boolean> | boolean
    if not virtualListData then return false end

    return Computed(scope, function(use, scope): boolean
        local usedMapAbsolutePosition =
            use<<Vector2>>(virtualListData.MapAbsolutePosition)
        local usedMapAbsoluteSize =
            use<<Vector2>>(virtualListData.MapAbsoluteSize)

        local usedViewportAbsolutePosition =
            use<<Vector2>>(virtualListData.ViewportAbsolutePosition)
        local usedViewportAbsoluteSize =
            use<<Vector2>>(virtualListData.ViewportAbsoluteSize)
        local usedOverdraw = math.max(use<<number>>(virtualListData.Overdraw), 0)

        local mapTopY = usedMapAbsolutePosition.Y
        local mapBottomY = mapTopY + usedMapAbsoluteSize.Y

        local viewportTopY = usedViewportAbsolutePosition.Y - usedOverdraw
        local viewportBottomY = usedViewportAbsolutePosition.Y
            + usedViewportAbsoluteSize.Y
            + usedOverdraw

        return mapBottomY <= viewportTopY or mapTopY >= viewportBottomY
    end)
end

return {
    CalculateMapRowCount = CalculateMapRowCount,
    CalculateMapHeight = CalculateMapHeight,
    ComputeVirtualListOccludesMap = ComputeVirtualListOccludesMap
}
