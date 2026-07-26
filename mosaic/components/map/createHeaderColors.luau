--!strict

local Packages = script.Parent.Parent.Parent.Parent

local Fusion = require(Packages.fusion)
local Computed = Fusion.Computed

local Types = require(script.Parent.types)
local TintHeaderColor = require(script.Parent.headerColorTint)

type HeaderColors = Types.HeaderColors
type TintTarget = TintHeaderColor.TintTarget

type HeaderColorConfig = {
    Header: string,
    PreviousHeader: string?,
    HeaderColorTint: Fusion.UsedAs<boolean>,
    BackgroundBaseColor3: Fusion.UsedAs<Color3>,
    ForegroundBaseColor3: Fusion.UsedAs<Color3>,
}

local function CreateHeaderColors(
    scope: Fusion.Scope,
    config: HeaderColorConfig
): HeaderColors
    local function computeHeaderColor(
        headerBaseColor: Fusion.UsedAs<Color3>,
        target: TintTarget
    ): Fusion.Computed<Color3>
        return Computed(scope, function(use: Fusion.Use): Color3
            local usedHeaderBaseColor =
                use<<Color3>>(headerBaseColor)

            if not use<<boolean>>(config.HeaderColorTint) then
                return usedHeaderBaseColor
            end

            return TintHeaderColor(
                usedHeaderBaseColor,
                config.Header,
                target,
                config.PreviousHeader
            )
        end)
    end

    return {
        BackgroundColor3 = computeHeaderColor(
            config.BackgroundBaseColor3,
            "Background"
        ),
        ForegroundColor3 = computeHeaderColor(
            config.ForegroundBaseColor3,
            "Foreground"
        ),
    }
end

return CreateHeaderColors
