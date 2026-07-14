--!strict

local Packages = script.Parent.Parent.Parent.Parent
local Fusion = require(Packages.fusion)

local Computed, ForValues = Fusion.Computed, Fusion.ForValues

local function ForCount<VO, S>(
    scope: S & Fusion.Scope<unknown>,
    start: Fusion.UsedAs<number>,
    finish: Fusion.UsedAs<number>,
    step: Fusion.UsedAs<number>,
    processor: (Fusion.Use, S, number) -> VO
): Fusion.For<number, VO>
    local range = Computed(
        scope,
        function(use: Fusion.Use): { [number]: number }
            local usedStart = use<<number>>(start)
            local usedFinish = use<<number>>(finish)
            local usedStep = use<<number>>(step)

            assert(usedStep ~= 0, "ForCount step must not be zero")

            local resultCount = math.max(
                math.floor((usedFinish - usedStart) / usedStep) + 1,
                0
            )
            local result =
                table.create(resultCount) :: { [number]: number }

            for index = usedStart, usedFinish, usedStep do
                result[index] = index
            end

            return result
        end
    )

    return ForValues(scope, range, processor)
end

return ForCount
