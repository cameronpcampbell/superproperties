--!strict

local Types = require(script.Parent.types)

local function DefaultThemeConfig(): Types.ThemeConfig
    return {
        BgBaseColor = settings().Studio.Theme:GetColor(Enum.StudioStyleGuideColor.MainBackground),

        AccentPrimary = settings().Studio.Theme:GetColor(Enum.StudioStyleGuideColor.DialogMainButton),
        AccentSecondary = settings().Studio.Theme:GetColor(Enum.StudioStyleGuideColor.DialogMainButton),
        AccentCaution = Color3.fromHex("A47103"),
        AccentDestructive = Color3.fromHex("#BE123C"),

        HeightSm = 13,
        HeightMd = 18,
        HeightLg = 25,

        FontMain = Font.fromName("BuilderSans"),
        FontMono = Font.fromName("BuilderSansMono"),

        FontMainTitleSize = 15,
        FontMainBodySize = 15,
        FontMainCaptionSize = 12,

        FontMonoTitleSize = 14,
        FontMonoBodySize = 14,
        FontMonoCaptionSize = 13
    }
end

return DefaultThemeConfig
