--!strict

local Packages = script.Parent.Parent.Parent.Parent

local Fusion = require(Packages.fusion)
local Computed = Fusion.Computed

local RowGap = 1
local MapContentPadding = 1

export type VirtualListData = {
    AnimatedMapSize: Fusion.Tween<UDim2>?,
    GeometryReady: Fusion.UsedAs<boolean>,
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

local function CalculateMapTopSpacerHeight(
    skippedRowCount: number,
    lgHeight: number
): number
    if skippedRowCount <= 0 then return 0 end

    local rowHeight = lgHeight - 2

    return rowHeight * skippedRowCount
        + RowGap * (skippedRowCount - 1)
end

local function ComputeVirtualListVisibleRowRange(
    scope: Fusion.Scope,
    virtualListData: VirtualListData?,
    rowCount: Fusion.UsedAs<number>,
    lgHeight: number
): Fusion.Computed<Vector2>?
    if not virtualListData then return nil end

    return Computed(scope, function(use): Vector2
        if not use<<boolean>>(virtualListData.GeometryReady) then
            return Vector2.new(1, 0)
        end

        local usedRowCount = use<<number>>(rowCount)
        if usedRowCount <= 0 then return Vector2.new(1, 0) end

        local usedMapAbsolutePosition =
            use<<Vector2>>(virtualListData.MapAbsolutePosition)
        local usedViewportAbsolutePosition =
            use<<Vector2>>(virtualListData.ViewportAbsolutePosition)
        local usedViewportAbsoluteSize =
            use<<Vector2>>(virtualListData.ViewportAbsoluteSize)
        local usedOverdraw = math.max(use<<number>>(virtualListData.Overdraw), 0)

        local rowHeight = lgHeight - 2
        local rowStride = rowHeight + RowGap
        local contentTopY = usedMapAbsolutePosition.Y + MapContentPadding

        local viewportTopY = usedViewportAbsolutePosition.Y - usedOverdraw
        local viewportBottomY = usedViewportAbsolutePosition.Y
            + usedViewportAbsoluteSize.Y
            + usedOverdraw

        local firstRow = math.floor(
            (viewportTopY - contentTopY - rowHeight) / rowStride
        ) + 2

        local lastRow = math.ceil(
            (viewportBottomY - contentTopY) / rowStride
        )

        if lastRow < 1 or firstRow > usedRowCount or firstRow > lastRow then
            return Vector2.new(1, 0)
        end

        return Vector2.new(
            math.clamp(firstRow, 1, usedRowCount),
            math.clamp(lastRow, 1, usedRowCount)
        )
    end)
end

local function ComputeVirtualListOccludesMap(
    scope: Fusion.Scope,
    virtualListData: VirtualListData?
): Fusion.Computed<boolean> | boolean
    if not virtualListData then return false end

    return Computed(scope, function(use, scope): boolean
        if not use<<boolean>>(virtualListData.GeometryReady) then
            return true
        end

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
    CalculateMapTopSpacerHeight = CalculateMapTopSpacerHeight,
    ComputeVirtualListVisibleRowRange = ComputeVirtualListVisibleRowRange,
    ComputeVirtualListOccludesMap = ComputeVirtualListOccludesMap
}
