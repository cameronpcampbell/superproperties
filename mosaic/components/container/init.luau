--!strict
--!nolint LocalShadow

local Packages = script.Parent.Parent.Parent
local Supercorner = require(Packages.supercorner)

local Fusion = require(Packages.fusion)
local Children, New, Peek = Fusion.Children, Fusion.New, Fusion.peek

local Utils = script.Parent.Parent.utils

local FusionUtils = require(Utils.fusionUtils)
local Component, CombineProps, ComposeTransparency, ComputeAdd =
    FusionUtils.Component, FusionUtils.CombineProps,
    FusionUtils.ComposeTransparency, FusionUtils.ComputeMath.Add

local ThemeUtils = require(Utils.themeUtils)
local GetThemeForScope, GetNextVariant =
    ThemeUtils.GetThemeForScope, ThemeUtils.GetNextVariant

local TableUtils = require(Utils.tableUtils)
local TableExtract = TableUtils.Extract

type ContainerProps = {
	Variant: ThemeUtils.BgVariantLayer?,
	CornerRadius: ThemeUtils.CornerRadiusVariant?,
	CornerRadiusOffset: number?,
	AutomaticSize: Enum.AutomaticSize?,
	ContentZIndex: Fusion.UsedAs<number>?,
	Transparency: Fusion.UsedAs<number>?,
	[string | Fusion.SpecialKey]: any
}

return Component<<ContainerProps>>(function(scope, props)
    local props, variant = TableExtract(props, "Variant", "Primary")
    local props, cornerRadiusVariant =
        TableExtract(props, "CornerRadius", "Md")
    local props, cornerRadiusOffset =
        TableExtract(props, "CornerRadiusOffset", 0)
    local props, automaticSize =
        TableExtract(props, "AutomaticSize", Enum.AutomaticSize.None)
    local props, contentZIndex =
        TableExtract(props, "ContentZIndex", 2)
    local props, transparency = TableExtract(props, "Transparency", 0)
    local props, backgroundTransparency =
        TableExtract(props, "BackgroundTransparency", 0)
    local props, strokeTransparency =
        TableExtract(props, "StrokeTransparency", 0)
    local props, children = TableExtract(props, Children)
    local props, rootChildren = TableExtract(props, "RootChildren")

    local theme = GetThemeForScope(scope)
    local bgColor = theme:GetBg(scope, variant)
    local strokeColor = theme:GetBg(scope, GetNextVariant(scope, variant))
    local cornerRadius = ComputeAdd(
        scope,
        theme:GetCornerRadius(scope, cornerRadiusVariant),
        cornerRadiusOffset
    )
    local composedBackgroundTransparency = ComposeTransparency(
        scope,
        backgroundTransparency,
        transparency
    )
    local composedStrokeTransparency = ComposeTransparency(
        scope,
        strokeTransparency,
        transparency
    )

    local automaticSizeContent: Fusion.Child? = nil
    local regularContent: Fusion.Child? = children

    if automaticSize == Enum.AutomaticSize.Y
        or automaticSize == Enum.AutomaticSize.XY
    then
        -- Supercorner places regular children in a full-size intermediate
        -- frame. Roblox cannot derive the root's automatic height through
        -- that scaled frame, so mount auto-sized content directly at root.
        automaticSizeContent = New(scope, "Frame") {
            Size =
                if automaticSize == Enum.AutomaticSize.XY then
                    UDim2.fromOffset(0, 0)
                else UDim2.new(1, 0, 0, 0),
            AutomaticSize = automaticSize,
            BackgroundTransparency = 1,
            ZIndex = contentZIndex,

            Name = "ContainerContent",

            [Children] = children
        }
        regularContent = nil
    end

    return Supercorner.new(scope, CombineProps({
        Name = "Container",

        BackgroundColor3 = bgColor,
        BackgroundTransparency = composedBackgroundTransparency,
        StrokeColor = strokeColor,
        StrokeThickness = 1,
        StrokeTransparency = composedStrokeTransparency,
        Size = UDim2.fromScale(1, 1),
        AutomaticSize = automaticSize,
        CornerRadius = Peek<<number>>(cornerRadius),
        CornerSmoothing = 1,
        RootChildren = {
            rootChildren,
            automaticSizeContent
        },

        [Children] = regularContent
    }, props))
end)
