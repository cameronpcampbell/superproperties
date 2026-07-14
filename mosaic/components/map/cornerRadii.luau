--!strict

local Packages = script.Parent.Parent.Parent.Parent
local Fusion = require(Packages.fusion)
local Computed = Fusion.Computed

export type RowSide = "Left" | "Right"

local function CalculateRowCornerRadii(
    scope: Fusion.Scope,
    side: RowSide,
    rowCount: Fusion.UsedAs<number>,
    rowIdx: Fusion.UsedAs<number>,
    radius: number
): (
    Fusion.Computed<number>, Fusion.Computed<number>,
    Fusion.Computed<number>, Fusion.Computed<number>
)
    local topRadius = Computed(scope, function(use): number
        return if use<<number>>(rowIdx) == 1 then radius else 0
    end)
    local bottomRadius = Computed(scope, function(use): number
        return
            if use<<number>>(rowIdx) == use<<number>>(rowCount)
            then radius
            else 0
    end)
    local zero = Computed(scope, function(): number return 0 end)

    if side == "Left" then
        return topRadius, zero, bottomRadius, zero
    end

    return zero, topRadius, zero, bottomRadius
end

return CalculateRowCornerRadii
