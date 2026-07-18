--!strict
--!nolint LocalShadow

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

type Value<T, S = T> = Fusion.Value<T, S>

type function mapTable(input: type, map: (ty: type) -> type)
    assert(input.tag, "table")

    for key, value in input:properties() do
        local value = value.read or value.write
        if not value then continue end

        input:setproperty(key, map(value))
    end

    return input
end

type function MapThemeToValue(input: type)
    return mapTable(input, function(ty)
        return Value(ty)
    end)
end

export type ThemeConfig = {
    BgBaseColor: Color3,

    AccentPrimary: Color3,
    AccentSecondary: Color3,
    AccentDestructive: Color3,

    HeightSm: number,
    HeightMd: number,
    HeightLg: number,

    -- We force all corner radii to be the same for all
    -- themes as an optimization due to supercorner.
    --CornerRadiusSm: number,
    --CornerRadiusMd: number,
    --CornerRadiusLg: number,

    FontMain: Font,
    FontMono: Font,

    FontMainTitleSize: number,
    FontMainBodySize: number,
    FontMainCaptionSize: number,

    FontMonoTitleSize: number,
    FontMonoBodySize: number,
    FontMonoCaptionSize: number,
}

export type ThemeSource = {
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

    AccentFgPrimary: Color3,
    AccentFgSecondary: Color3,
    AccentFgTertiary: Color3,

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

export type Theme = {
    BgPrimary: Fusion.UsedAs<Color3>,
    BgSecondary: Fusion.UsedAs<Color3>,
    BgTertiary: Fusion.UsedAs<Color3>,
    BgQuaternary: Fusion.UsedAs<Color3>,
    BgQuinary: Fusion.UsedAs<Color3>,

    BgPrimaryHighlight: Fusion.UsedAs<Color3>,
    BgSecondaryHighlight: Fusion.UsedAs<Color3>,
    BgTertiaryHighlight: Fusion.UsedAs<Color3>,
    BgQuaternaryHighlight: Fusion.UsedAs<Color3>,
    BgQuinaryHighlight: Fusion.UsedAs<Color3>,

    FgPrimary: Fusion.UsedAs<Color3>,
    FgSecondary: Fusion.UsedAs<Color3>,
    FgTertiary: Fusion.UsedAs<Color3>,

    AccentPrimary: Fusion.UsedAs<Color3>,
    AccentSecondary: Fusion.UsedAs<Color3>,
    AccentDestructive: Fusion.UsedAs<Color3>,

    AccentFgPrimary: Fusion.UsedAs<Color3>,
    AccentFgSecondary: Fusion.UsedAs<Color3>,
    AccentFgTertiary: Fusion.UsedAs<Color3>,

    HeightSm: Fusion.UsedAs<number>,
    HeightMd: Fusion.UsedAs<number>,
    HeightLg: Fusion.UsedAs<number>,

    CornerRadiusSm: Fusion.UsedAs<number>,
    CornerRadiusMd: Fusion.UsedAs<number>,
    CornerRadiusLg: Fusion.UsedAs<number>,

    FontMain: Fusion.UsedAs<Font>,
    FontMono: Fusion.UsedAs<Font>,

    FontMainTitleSize: Fusion.UsedAs<number>,
    FontMainBodySize: Fusion.UsedAs<number>,
    FontMainCaptionSize: Fusion.UsedAs<number>,

    FontMonoTitleSize: Fusion.UsedAs<number>,
    FontMonoBodySize: Fusion.UsedAs<number>,
    FontMonoCaptionSize: Fusion.UsedAs<number>,

    [string]: Fusion.UsedAs<unknown>,

    GetBg: (
        theme: Theme,
        scope: Fusion.Scope,
        variant: Fusion.UsedAs<BgVariant>,
        modifier: Fusion.UsedAs<ThemeColorModifier?>
    ) -> Fusion.UsedAs<Color3>,

    GetBgHighlight: (
        theme: Theme,
        scope: Fusion.Scope,
        variant: Fusion.UsedAs<BgVariantLayer>,
        modifier: Fusion.UsedAs<ThemeColorModifier?>
    ) -> Fusion.UsedAs<Color3>,

    GetFg: (
        theme: Theme,
        scope: Fusion.Scope,
        variant: Fusion.UsedAs<FgVariant>,
        modifier: Fusion.UsedAs<ThemeColorModifier?>
    ) -> Fusion.UsedAs<Color3>,

    GetAccent: (
        theme: Theme,
        scope: Fusion.Scope,
        variant: Fusion.UsedAs<AccentVariant>,
        modifier: Fusion.UsedAs<ThemeColorModifier?>
    ) -> Fusion.UsedAs<Color3>,

    GetAccentFg: (
        theme: Theme,
        scope: Fusion.Scope,
        variant: Fusion.UsedAs<FgVariant>
    ) -> Fusion.UsedAs<Color3>,

    GetHeight: (
        theme: Theme,
        scope: Fusion.Scope,
        variant: Fusion.UsedAs<HeightVariant>
    ) -> Fusion.UsedAs<number>,

    GetCornerRadius: (
        theme: Theme,
        scope: Fusion.Scope,
        variant: Fusion.UsedAs<CornerRadiusVariant>
    ) -> Fusion.UsedAs<number>,

    GetFont: (
        theme: Theme,
        scope: Fusion.Scope,
        variant: Fusion.UsedAs<FontVariant>,
        weight: Fusion.UsedAs<Enum.FontWeight?>,
        style: Fusion.UsedAs<Enum.FontStyle?>
    ) -> Fusion.UsedAs<Font>,

    GetFontSize: (
        theme: Theme,
        scope: Fusion.Scope,
        variant: Fusion.UsedAs<FontVariant>,
        sizeVariant: Fusion.UsedAs<FontSizeVariant>
    ) -> Fusion.UsedAs<number>,

    HighlightGradient: (
        theme: Theme,
        scope: Fusion.Scope,
        transparency: Fusion.UsedAs<number>
    ) -> UIGradient
}
return nil
