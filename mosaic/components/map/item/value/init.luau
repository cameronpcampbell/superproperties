--!strict
--!nolint LocalShadow

local Packages = script.Parent.Parent.Parent.Parent.Parent
local Supercorner = require(Packages.supercorner)
local Typeforge = require(Packages.typeforge)

local Fusion = require(Packages.fusion)
local New, Children, Value, Computed, OnEvent, Tween =
    Fusion.New, Fusion.Children, Fusion.Value,
    Fusion.Computed, Fusion.OnEvent, Fusion.Tween

local Utils = script.Parent.Parent.Parent.Parent.utils

local FusionUtils = require(Utils.fusionUtils)
local ComputeTransforms = FusionUtils.ComputeTransforms
local ComputeUDim2, ComputeUDim = ComputeTransforms.UDim2, ComputeTransforms.UDim
local ComputeMath = FusionUtils.ComputeMath
local ComputeAdd = ComputeMath.Add

local ThemeUtils = require(Utils.themeUtils)
local GetThemeForScope, CalcColorModifier, GetNextVariant =
    ThemeUtils.GetThemeForScope, ThemeUtils.CalcColorModifier,
    ThemeUtils.GetNextVariant

local Types = require(script.Parent.Parent.types)
local CalculateRowCornerRadii =
    require(script.Parent.Parent.cornerRadii)

local ValueVariants = require(script.variants)
local DefaultValueVariant = ValueVariants.string

type MapItemValueProps = Typeforge.Flatten<
    Types.BaseMapProps & {
        Value: any,
        Writable: boolean,
        TrySetValue: Types.TrySetValue<any>?,
        Redrawable: boolean
    }
>

local function RoundColor(color: Color3, dp: number): Color3
    local scale = 10 ^ dp

    return Color3.new(
        math.round(color.R * scale) / scale,
        math.round(color.G * scale) / scale,
        math.round(color.B * scale) / scale
    )
end

local function MapItemValue(scope: Fusion.Scope, props: MapItemValueProps)
    local rowCount, rowIdx = props.RowCount, props.RowIdx
    local variant = props.Variant
    local value = props.Value

    local valueVariant: ValueVariants.ValueVariantFn<any> =
        (ValueVariants :: any)[typeof(value)] or
        DefaultValueVariant

    local isHoverState, isFocusState = Value(scope, false), Value(scope, false)
    local themeColorModifier =
        CalcColorModifier(scope, isHoverState, isFocusState, "Stroke")

    local theme = GetThemeForScope(scope)
    local bgColor = theme:GetBg(scope, variant)
    local accentColor = theme:GetAccent(scope, "Primary", themeColorModifier)
    local restingStrokeColor = theme:GetBg(scope, GetNextVariant(variant))
    local strokeColor = theme:GetBg(scope, GetNextVariant(variant), themeColorModifier)
    local rowHeight =
        ComputeAdd(scope, theme:GetHeight(scope, "Lg"), - 2)
    local innerCornerRadius =
        ComputeAdd(scope, theme:GetCornerRadius(scope, "Md"), - 1)

    local tweenComputeStrokeColor = Tween<<Color3>>(
        scope,
        Computed(scope, function(use, scope)
            return
                if use<<boolean>>(isFocusState) then
                    use<<Color3>>(accentColor)
                else
                    use<<Color3>>(strokeColor)
        end),
        TweenInfo.new(
            .18, Enum.EasingStyle.Exponential, Enum.EasingDirection.InOut
        )
    )

    local topLeftRadius, topRightRadius, bottomLeftRadius, bottomRightRadius =
        CalculateRowCornerRadii(
            scope,
            "Right",
            rowCount,
            rowIdx,
            props.Redrawable,
            innerCornerRadius
        )

    local shouldShowBorder = Computed(scope, function(use, scope)
        local usedTweenComputeStrokeColor = use<<Color3>>(tweenComputeStrokeColor)
        local usedRestingStrokeColor = use<<Color3>>(restingStrokeColor)

        return
            use<<boolean>>(isHoverState) or
            use<<boolean>>(isFocusState) or
            RoundColor(usedTweenComputeStrokeColor, 3) ~=
                RoundColor(usedRestingStrokeColor, 3)
    end)

    local border = Computed(scope, function(use, scope: Fusion.Scope): Fusion.Child?
        local usedShouldShowBorder = use<<boolean>>(shouldShowBorder)
        if not usedShouldShowBorder then return nil end

        return Supercorner.new(scope, {
            BackgroundTransparency = 1,
            StrokeColor = tweenComputeStrokeColor,
            StrokeThickness = 1,
            Size = UDim2.new(1, 2, 1, 2),
            TopLeftRadius = topLeftRadius,
            TopRightRadius = topRightRadius,
            BottomLeftRadius = bottomLeftRadius,
            BottomRightRadius = bottomRightRadius,
            MaxCornerRadius = if props.Redrawable then innerCornerRadius else nil,
            Redrawable = props.Redrawable,
            Position = UDim2.fromScale(.5, .5),
            AnchorPoint = Vector2.new(.5, .5)
        })
    end)

    return Supercorner.new(scope, {
        BackgroundColor3 = bgColor,
        Size = ComputeUDim2(scope, UDim.new(1, 0), ComputeUDim(scope, 0, rowHeight)),
        TopLeftRadius = topLeftRadius,
        TopRightRadius = topRightRadius,
        BottomLeftRadius = bottomLeftRadius,
        BottomRightRadius = bottomRightRadius,
        MaxCornerRadius = if props.Redrawable then innerCornerRadius else nil,
        Redrawable = props.Redrawable,
        LayoutOrder = 1,

        Name = "MapItemValue",

        [OnEvent "MouseEnter"] = function() isHoverState:set(true) end,
        [OnEvent "MouseLeave"] = function() isHoverState:set(false) end,

        RootChildren = border :: any,

        [Children] = {
            valueVariant(scope, {
                Value = value,
                Writable = props.Writable,
                TrySetValue = props.TrySetValue
            }),

            New(scope, "UIListLayout") {
                Padding = UDim.new(0, 6),
                FillDirection = Enum.FillDirection.Horizontal,
                VerticalAlignment = Enum.VerticalAlignment.Center,
                SortOrder = Enum.SortOrder.LayoutOrder
            },

            New(scope, "UIPadding") {
                PaddingLeft = UDim.new(0, 6),
                PaddingRight = UDim.new(0, 6)
            }
        }
    })
end

return MapItemValue
