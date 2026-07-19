--!strict

local Packages = script.Parent.Parent.Parent.Parent
local Fusion = require(Packages.fusion)
local Computed = Fusion.Computed

return function(
    scope: Fusion.Scope<typeof(Fusion)>,
    baseTransparency: Fusion.UsedAs<number>,
    extraTransparency: Fusion.UsedAs<number>
): Fusion.Computed<number>
    return Computed(scope, function(use: Fusion.Use): number
        local baseOpacity =
            1 - math.clamp(use<<number>>(baseTransparency), 0, 1)
        local extraOpacity =
            1 - math.clamp(use<<number>>(extraTransparency), 0, 1)

        return 1 - baseOpacity * extraOpacity
    end)
end
