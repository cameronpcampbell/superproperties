--!strict

local CreateTheme = require(script.createTheme)
local DefaultTheme = require(script.defaultTheme)
local ManageTheme = require(script.manageTheme)
local Types = require(script.types)
local ThemeHelpers = require(script.themeHelpers)

export type Theme = Types.Theme
export type ThemeConfig = Types.ThemeConfig

export type BgVariant = Types.BgVariant
export type BgFirstVariant = Types.BgFirstVariant
export type BgLastVariant = Types.BgLastVariant
export type BgVariantLayer = Types.BgVariantLayer

export type FgVariant = Types.FgVariant

export type AccentVariant = Types.AccentVariant

export type HeightVariant = Types.HeightVariant

export type CornerRadiusVariant = Types.CornerRadiusVariant

export type FontVariant = Types.FontVariant
export type FontSizeVariant = Types.FontSizeVariant

export type ThemeColorModifier = Types.ThemeColorModifier

local function GetNextVariant(variant: BgVariantLayer): BgVariant
    return
        if variant == "Primary" then "Secondary"
        elseif variant == "Secondary" then "Tertiary"
        elseif variant == "Tertiary" then "Quaternary"
        elseif variant == "Quaternary" then "Quinary"
        else "Secondary"
end

return {
    CreateTheme = CreateTheme,
    DefaultTheme = DefaultTheme,
    SetThemeForScope = ManageTheme.SetThemeForScope,
    GetThemeForScope = ManageTheme.GetThemeForScope,
    GetNextVariant = GetNextVariant,
    CalcColorModifier = ThemeHelpers.CalcColorModifier
}
