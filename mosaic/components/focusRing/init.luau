--!strict
--!nolint LocalShadow

local Packages = script.Parent.Parent.Parent
local Supercorner = require(Packages.supercorner)

local Fusion = require(Packages.fusion)
local Tween, Computed = Fusion.Tween, Fusion.Computed

local Utils = script.Parent.Parent.utils

local FusionUtils = require(Utils.fusionUtils)
local Component, CombineProps =
    FusionUtils.Component, FusionUtils.CombineProps

local ThemeUtils = require(Utils.themeUtils)
local GetThemeForScope = ThemeUtils.GetThemeForScope

local TableUtils = require(Utils.tableUtils)
local TableExtract = TableUtils.Extract

type FocusRingProps = {
    CornerRadius: number?,
	TopLeftRadius: number?,
	TopRightRadius: number?,
	BottomRightRadius: number?,
	BottomLeftRadius: number?,
	IsFocus: Fusion.UsedAs<boolean>,
	CullWhenHidden: boolean?
}

return Component<<FocusRingProps>>(function(scope, props)
    local props, cornerRadius = TableExtract(props, "CornerRadius")
    local props, topLeftRadius = TableExtract(props, "TopLeftRadius")
    local props, topRightRadius = TableExtract(props, "TopRightRadius")
    local props, bottomRightRadius = TableExtract(props, "BottomRightRadius")
    local props, bottomLeftRadius = TableExtract(props, "BottomLeftRadius")
    local props, isFocus = TableExtract(props, "IsFocus")
    local props, cullWhenHidden = TableExtract(props, "CullWhenHidden", false)

    local ringThickness = 2
    local ringInset = .5
    local unfocusOffset = ringThickness + 8

    local computeAlpha = Tween<<number>>(
        scope,
        Computed(scope, function(use, scope)
            return if use<<boolean>>(isFocus) then 1 else 0
        end),
        TweenInfo.new(
            .23, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut
        )
    )

    local computeSize = Computed(scope, function(use, scope)
        local usedAlpha = use<<number>>(computeAlpha)
        local sizeOffset = math.map(usedAlpha, 0, 1, unfocusOffset, ringThickness * 2)

        return UDim2.new(1, sizeOffset + ringInset, 1, sizeOffset + ringInset)
    end)

    local computeTransparency = Computed(scope, function(use, scope)
        local usedAlpha = use<<number>>(computeAlpha)

        return math.map(usedAlpha, 0, 1, 1, .6)
    end)

    local theme = GetThemeForScope(scope)
    local accentColor = theme:GetAccent(scope, "Primary")

    local function createRing(ringScope: Fusion.Scope): Fusion.Child
        return Supercorner.new(ringScope, CombineProps({
            Size = computeSize,
            Position = UDim2.fromScale(.5, .5),
            AnchorPoint = Vector2.new(.5, .5),
            StrokeThickness = ringThickness + ringInset,
            StrokeTransparency = computeTransparency,
            StrokeColor = accentColor,
            BackgroundTransparency = 1,
            ForceSupercorner = true,
            CornerRadius =
                if cornerRadius then cornerRadius + ringThickness else nil,
            TopLeftRadius =
                if topLeftRadius then topLeftRadius + ringThickness else nil,
            TopRightRadius =
                if topRightRadius then topRightRadius + ringThickness else nil,
            BottomRightRadius =
                if bottomRightRadius then bottomRightRadius + ringThickness else nil,
            BottomLeftRadius =
                if bottomLeftRadius then bottomLeftRadius + ringThickness else nil,
            CornerSmoothing = 1,
            ZIndex = 0,
        }, props :: any))
    end

    if not cullWhenHidden then return createRing(scope) end

    local shouldShow = Computed(scope, function(use, scope): boolean
        return
            use<<boolean>>(isFocus) or
            use<<number>>(computeAlpha) > .001
    end)

    return Computed(scope, function(use, scope): Fusion.Child
        if not use<<boolean>>(shouldShow) then return nil :: any end
        return createRing(scope)
    end)
end)
