--!strict

local Packages = script.Parent.Parent.Parent.Parent
local Fusion = require(Packages.fusion)
local Typeforge = require(Packages.typeforge)

export type BgVariant = "Primary" | "Secondary" | "Tertiary" | "Quaternary" | "Quinary"
export type BgFirstVariant = "Primary"
export type BgLastVariant = "Quinary"
export type BgVariantLayer = Typeforge.Omit<BgVariant, BgLastVariant>

export type FgVariant = "Primary" | "Secondary" | "Tertiary"

export type AccentVariant = "Primary" | "Secondary" | "Destructive"

export type HeightVariant = "Sm" | "Md" | "Lg"

export type CornerRadiusVariant = "Sm" | "Md" | "Lg"

export type FontVariant = "Main" | "Mono"
export type FontSizeVariant = "Title" | "Body" | "Caption"

export type ThemeColorModifier = "Hover" | "Press" | "HoverStroke"

export type Theme = {
    BgPrimary: Color3,
    BgSecondary: Color3,
    BgTertiary: Color3,
    BgQuaternary: Color3,
    BgQuinary: Color3,

    BgPrimaryHighlight: Color3,
    BgSecondaryHighlight: Color3,
    BgTertiaryHighlight: Color3,
    BgQuaternaryHighlight: Color3,

    FgPrimary: Color3,
    FgSecondary: Color3,
    FgTertiary: Color3,

    AccentPrimary: Color3,
    AccentSecondary: Color3,
    AccentDestructive: Color3,

    HeightSm: number,
    HeightMd: number,
    HeightLg: number,

    CornerRadiusSm: number,
    CornerRadiusMd: number,
    CornerRadiusLg: number,

    FontMain: Font,
    FontMono: Font,

    FontMainTitleSize: number,
    FontMainBodySize: number,
    FontMainCaptionSize: number,

    FontMonoTitleSize: number,
    FontMonoBodySize: number,
    FontMonoCaptionSize: number,

    GetBg: (
        theme: Theme,
        scope: Fusion.Scope,
        variant: BgVariant,
        modifier: Fusion.UsedAs<ThemeColorModifier?>
    ) -> Fusion.Computed<Color3>,
    GetBgHighlight: (
        theme: Theme,
        scope: Fusion.Scope,
        variant: BgVariantLayer,
        modifier: Fusion.UsedAs<ThemeColorModifier?>
    ) -> Fusion.Computed<Color3>,
    GetFg: (
        theme: Theme,
        scope: Fusion.Scope,
        variant: FgVariant,
        modifier: Fusion.UsedAs<ThemeColorModifier?>
    ) -> Fusion.Computed<Color3>,
    GetAccent: (
        theme: Theme,
        scope: Fusion.Scope,
        variant: AccentVariant,
        modifier: Fusion.UsedAs<ThemeColorModifier?>
    ) -> Fusion.Computed<Color3>,
    GetHeight: (theme: Theme, variant: HeightVariant) -> number,
    GetCornerRadius: (theme: Theme, variant: CornerRadiusVariant) -> number,
    GetFont: (
        theme: Theme,
        variant: FontVariant,
        weight: Enum.FontWeight?,
        style: Enum.FontStyle?
    ) -> Font,
    GetFontSize: (theme: Theme, variant: FontVariant, sizeVariant: FontSizeVariant) -> number,

    HighlightGradient: (theme: Theme, scope: Fusion.Scope, transparency: number) -> UIGradient
}

export type ThemeConfig = {
    BgBaseColor: Color3,

    AccentPrimary: Color3,
    AccentSecondary: Color3,
    AccentDestructive: Color3,

    HeightSm: number,
    HeightMd: number,
    HeightLg: number,

    CornerRadiusSm: number,
    CornerRadiusMd: number,
    CornerRadiusLg: number,

    FontMain: Font,
    FontMono: Font,

    FontMainTitleSize: number,
    FontMainBodySize: number,
    FontMainCaptionSize: number,

    FontMonoTitleSize: number,
    FontMonoBodySize: number,
    FontMonoCaptionSize: number,
}

return nil
