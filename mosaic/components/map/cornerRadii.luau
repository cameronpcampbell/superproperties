--!strict

local Packages = script.Parent.Parent.Parent.Parent
local Fusion = require(Packages.fusion)
local Computed, Peek = Fusion.Computed, Fusion.peek

export type RowSide = "Left" | "Right"

local function CalculateRowCornerRadii(
    scope: Fusion.Scope,
    side: RowSide,
    rowCount: Fusion.UsedAs<number>,
    rowIdx: Fusion.UsedAs<number>,
    redrawable: boolean,
    radius: number
): (
    Fusion.UsedAs<number>, Fusion.UsedAs<number>,
    Fusion.UsedAs<number>, Fusion.UsedAs<number>
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

    local function resolve(radiusState: Fusion.Computed<number>): Fusion.UsedAs<number>
        return
            if redrawable then radiusState
            else Peek<<number>>(radiusState)
    end

    if side == "Left" then
        return
            resolve(topRadius),
            resolve(zero),
            resolve(bottomRadius),
            resolve(zero)
    end

    return
        resolve(zero),
        resolve(topRadius),
        resolve(zero),
        resolve(bottomRadius)
end

return CalculateRowCornerRadii
