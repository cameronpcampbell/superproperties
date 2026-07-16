--!strict

local Packages = script.Parent.Parent.Parent.Parent
local Fusion = require(Packages.fusion)
local Computed, Peek = Fusion.Computed, Fusion.peek

export type RowSide = "Left" | "Right" | "Both"

local function CalculateRowCornerRadii(
    scope: Fusion.Scope,
    side: RowSide,
    rowCount: Fusion.UsedAs<number>,
    rowIdx: Fusion.UsedAs<number>,
    redrawable: boolean,
    radius: Fusion.UsedAs<number>
): (
    Fusion.UsedAs<number>, Fusion.UsedAs<number>,
    Fusion.UsedAs<number>, Fusion.UsedAs<number>
)
    local topRadius = Computed(scope, function(use: Fusion.Use): number
        return
            if use<<number>>(rowIdx) == 1
            then use<<number>>(radius)
            else 0
    end)

    local bottomRadius = Computed(scope, function(use: Fusion.Use): number
        return
            if use<<number>>(rowIdx) == use<<number>>(rowCount)
            then use<<number>>(radius)
            else 0
    end)

    local function resolve(radiusState: Fusion.UsedAs<number>): Fusion.UsedAs<number>
        return
            if redrawable then radiusState
            else Peek<<number>>(radiusState)
    end

    local useLeft = side ~= "Right"
    local useRight = side ~= "Left"
    return
        resolve(if useLeft then topRadius else 0),
        resolve(if useRight then topRadius else 0),
        resolve(if useLeft then bottomRadius else 0),
        resolve(if useRight then bottomRadius else 0)
end

return CalculateRowCornerRadii
