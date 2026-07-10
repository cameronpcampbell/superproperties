--!strict

local CreateTheme = require(script.Parent.createTheme)

return CreateTheme({
    BgBaseColor = settings().Studio.Theme:GetColor(Enum.StudioStyleGuideColor.MainBackground),

    AccentPrimary = settings().Studio.Theme:GetColor(Enum.StudioStyleGuideColor.MainButton),
    AccentSecondary = settings().Studio.Theme:GetColor(Enum.StudioStyleGuideColor.MainButton),
    AccentDestructive = settings().Studio.Theme:GetColor(Enum.StudioStyleGuideColor.MainButton),

    HeightSm = 13,
    HeightMd = 18,
    HeightLg = 25,

    CornerRadiusSm = 3,
    CornerRadiusMd = 6,
    CornerRadiusLg = 9,

    FontMain = Font.fromName("BuilderSans"),
    FontMono = Font.fromName("BuilderSansMono"),

    FontMainTitleSize = 15,
    FontMainBodySize = 15,
    FontMainCaptionSize = 12,

    FontMonoTitleSize = 14,
    FontMonoBodySize = 14,
    FontMonoCaptionSize = 13,
})
