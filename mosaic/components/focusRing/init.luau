--!strict
--!nolint LocalShadow

local Packages = script.Parent.Parent.Parent
local Supercorner = require(Packages.supercorner)

local Fusion = require(Packages.fusion)
local Tween, Computed, Observer, Peek =
    Fusion.Tween, Fusion.Computed, Fusion.Observer, Fusion.peek

local Utils = script.Parent.Parent.utils

local FusionUtils = require(Utils.fusionUtils)
local Component, CombineProps, ComposeTransparency, Oktween =
    FusionUtils.Component, FusionUtils.CombineProps,
    FusionUtils.ComposeTransparency, FusionUtils.Oktween

local ThemeUtils = require(Utils.themeUtils)
local GetThemeForScope = ThemeUtils.GetThemeForScope

local TableUtils = require(Utils.tableUtils)
local TableExtract = TableUtils.Extract

local CoreComponents = script.Parent.Parent.coreComponents
local TransparencyGated = require(CoreComponents.transparencyGated)

type FocusRingProps = {
    Variant: Fusion.UsedAs<ThemeUtils.AccentVariant>,
    BaseSize: Fusion.UsedAs<UDim2>?,
    CornerRadius: Fusion.UsedAs<number>?,
	TopLeftRadius: Fusion.UsedAs<number>?,
	TopRightRadius: Fusion.UsedAs<number>?,
	BottomRightRadius: Fusion.UsedAs<number>?,
	BottomLeftRadius: Fusion.UsedAs<number>?,
	MaxCornerRadius: Fusion.UsedAs<number>?,
	Redrawable: boolean?,
	IsFocus: Fusion.UsedAs<boolean>,
	CullWhenHidden: boolean?,
	TransitionTweenInfo: Fusion.UsedAs<TweenInfo>?,
    Transparency: Fusion.UsedAs<number>?,
	AlphaOut: Fusion.Value<number>?
}

local DefaultTransitionTweenInfo = TweenInfo.new(
    .23,
    Enum.EasingStyle.Quint,
    Enum.EasingDirection.InOut
)

return Component<<FocusRingProps>>(function(scope, props)
    local props, variant = TableExtract(props, "Variant", "Primary")
    local props, baseSize =
        TableExtract(props, "BaseSize", UDim2.new(1, 0, 1, 0))
    local props, cornerRadius = TableExtract(props, "CornerRadius")
    local props, topLeftRadius = TableExtract(props, "TopLeftRadius")
    local props, topRightRadius = TableExtract(props, "TopRightRadius")
    local props, bottomRightRadius = TableExtract(props, "BottomRightRadius")
    local props, bottomLeftRadius = TableExtract(props, "BottomLeftRadius")
    local props, maxCornerRadius = TableExtract(props, "MaxCornerRadius")
    local props, redrawable = TableExtract(props, "Redrawable", false)
    local props, isFocus = TableExtract(props, "IsFocus")
    local props, cullWhenHidden = TableExtract(props, "CullWhenHidden", true)
    local props, alphaOut = TableExtract(props, "AlphaOut")
    local props, transparency = TableExtract(props, "Transparency", 0)
    local props, transitionTweenInfo =
        TableExtract(
            props,
            "TransitionTweenInfo",
            DefaultTransitionTweenInfo
        )

    local ringThickness = 2
    local ringInset = .5
    local unfocusOffset = ringThickness + 8

    local function offsetRadius(
        radius: Fusion.UsedAs<number>?
    ): Fusion.UsedAs<number>?
        if radius == nil then return nil end
        if typeof(radius) == "number" then return radius + ringThickness end

        return Computed(scope, function(use: Fusion.Use): number
            return use<<number>>(radius) + ringThickness
        end)
    end

    local ringCornerRadius = offsetRadius(cornerRadius)
    local ringTopLeftRadius = offsetRadius(topLeftRadius)
    local ringTopRightRadius = offsetRadius(topRightRadius)
    local ringBottomRightRadius = offsetRadius(bottomRightRadius)
    local ringBottomLeftRadius = offsetRadius(bottomLeftRadius)
    local ringMaxCornerRadius = offsetRadius(maxCornerRadius)

    local computeAlpha = Tween<<number>>(
        scope,
        Computed(scope, function(use, scope)
            return if use<<boolean>>(isFocus) then 1 else 0
        end),
        transitionTweenInfo
    )

    if alphaOut then
        Observer(scope, computeAlpha):onBind(function()
            (alphaOut :: Fusion.Value<number>):set(Peek<<number>>(computeAlpha))
        end)
    end

    local computeSize = Computed(scope, function(use, scope)
        local usedBaseSize = use<<UDim2>>(baseSize)
        local usedAlpha = use<<number>>(computeAlpha)
        local sizeOffset = math.map(usedAlpha, 0, 1, unfocusOffset, ringThickness * 2)
        local animatedOffset =
            UDim2.new(0, sizeOffset + ringInset, 0, sizeOffset + ringInset)

        return usedBaseSize + animatedOffset
    end)

    local computeTransparency = Computed(scope, function(
        use: Fusion.Use
    ): number
        local usedAlpha = use<<number>>(computeAlpha)

        return math.map(usedAlpha, 0, 1, 1, .6)
    end)
    local composedTransparency = ComposeTransparency(
        scope,
        computeTransparency,
        transparency
    )

    local theme = GetThemeForScope(scope)
    local accentColor = theme:GetAccent(scope, variant)

    local ringProps = CombineProps({
        Size = computeSize,
        Position = UDim2.fromScale(.5, .5),
        AnchorPoint = Vector2.new(.5, .5),
        StrokeThickness = ringThickness + ringInset,
        StrokeTransparency = composedTransparency,
        StrokeColor = Oktween(
            scope, accentColor,
            TweenInfo.new(
                .18,
                Enum.EasingStyle.Exponential,
                Enum.EasingDirection.InOut
            )
        ),
        BackgroundTransparency = 1,
        ForceSupercorner = true,
        CornerRadius = ringCornerRadius,
        TopLeftRadius = ringTopLeftRadius,
        TopRightRadius = ringTopRightRadius,
        BottomRightRadius = ringBottomRightRadius,
        BottomLeftRadius = ringBottomLeftRadius,
        MaxCornerRadius = ringMaxCornerRadius,
        Redrawable = redrawable,
        CornerSmoothing = 1,
        ZIndex = 0,
    }, props :: any)

    if not cullWhenHidden then
        return Supercorner.new(scope, ringProps)
    end

    return TransparencyGated(scope, Supercorner.new :: any, CombineProps({
        GatedTransparencyProperty = "StrokeTransparency",
    }, ringProps))
end)
