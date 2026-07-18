--!strict

local Packages = script.Parent.Parent.Parent.Parent.packages

local Typeforge = require(Packages.typeforge)
type Omit<I, O> = Typeforge.Omit<I, O>

local Fusion = require(Packages.fusion)
local Computed = Fusion.Computed

local CreateTheme = require(script.createTheme)
local ManageTheme = require(script.manageTheme)
local Types = require(script.types)
local ThemeHelpers = require(script.themeHelpers)
local DefaultThemeConfig = require(script.defaultThemeConfig)

export type Theme = Types.Theme
export type ThemeSource = Types.ThemeSource
export type ThemeConfig = Types.ThemeConfig

export type BgVariant = Types.BgVariant
export type BgFirstVariant = Types.BgFirstVariant
export type BgLastVariant = Types.BgLastVariant
export type BgVariantLayer = Types.BgVariantLayer
export type BgVariantSubLayer = Types.BgVariantSubLayer

export type FgVariant = Types.FgVariant

export type AccentVariant = Types.AccentVariant

export type HeightVariant = Types.HeightVariant

export type CornerRadiusVariant = Types.CornerRadiusVariant

export type FontVariant = Types.FontVariant
export type FontSizeVariant = Types.FontSizeVariant

export type ThemeColorModifier = Types.ThemeColorModifier

type function IsState(input: any): boolean
    return
        input.tag == "table" and
        input:readproperty(types.singleton("type")) ==
            types.singleton("State")
end

type function ResolveNextVariantType(input: type)
    local value: type =
        if IsState(input) then
            input:readproperty(types.singleton("_EXTREMELY_DANGEROUS_usedAsValue")) :: type
        else input

    return
        if Omit(value, BgVariantSubLayer) == types.never then
            BgVariantLayer
        else BgVariant
end

local function GetNextVariant<V>(
    scope: Fusion.Scope,
    variant: V & (Fusion.UsedAs<BgVariantLayer> | Fusion.UsedAs<BgVariantSubLayer>)
): ResolveNextVariantType<V>
    return Computed(scope, function(use, scope)
        local usedVariant = use<<BgVariantLayer>>(variant)

        return
            if usedVariant == "Primary" then "Secondary"
            elseif usedVariant == "Secondary" then "Tertiary"
            elseif usedVariant == "Tertiary" then "Quaternary"
            elseif usedVariant == "Quaternary" then "Quinary"
            else "Secondary"
    end) :: any
end

return {
    CreateTheme = CreateTheme,
    SetThemeForScope = ManageTheme.SetThemeForScope,
    GetThemeForScope = ManageTheme.GetThemeForScope,
    GetNextVariant = GetNextVariant,
    CalcColorModifier = ThemeHelpers.CalcColorModifier,
    DefaultThemeConfig = DefaultThemeConfig
}
