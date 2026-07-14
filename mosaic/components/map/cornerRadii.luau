--!strict

export type RowSide = "Left" | "Right"

local function CalculateRowCornerRadii(
    side: RowSide,
    rowCount: number,
    rowIdx: number,
    radius: number
): (number, number, number, number)
    local topRadius = if rowIdx == 1 then radius else 0
    local bottomRadius = if rowIdx == rowCount then radius else 0

    if side == "Left" then
        return topRadius, 0, bottomRadius, 0
    end

    return 0, topRadius, 0, bottomRadius
end

return CalculateRowCornerRadii
