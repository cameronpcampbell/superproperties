--!strict
--!nolint LocalShadow

local Packages = script.Parent.Parent.Parent.Parent.Parent
local Supercorner = require(Packages.supercorner)
local Typeforge = require(Packages.typeforge)

local Fusion = require(Packages.fusion)
local New, Children, Computed, OnEvent, Tween, Peek =
    Fusion.New, Fusion.Children, Fusion.Computed, Fusion.OnEvent,
    Fusion.Tween, Fusion.peek

local Utils = script.Parent.Parent.Parent.Parent.utils

local FusionUtils = require(Utils.fusionUtils)
local CombineProps = FusionUtils.CombineProps
local ComputeTransforms = FusionUtils.ComputeTransforms
local ComputeUDim2, ComputeUDim = ComputeTransforms.UDim2, ComputeTransforms.UDim
local ComputeMath = FusionUtils.ComputeMath
local ComputeAdd = ComputeMath.Add

local ThemeUtils = require(Utils.themeUtils)
local GetThemeForScope, GetNextVariant, CalcColorModifier =
    ThemeUtils.GetThemeForScope, ThemeUtils.GetNextVariant, ThemeUtils.CalcColorModifier

local Types = require(script.Parent.Parent.types)

local Components = script.Parent.Parent.Parent
local FocusRing = require(Components.focusRing)

local CalculateRowCornerRadii =
    require(script.Parent.Parent.cornerRadii)

local ValueVariants = require(script.variants)
local DefaultValueVariant = ValueVariants.Default

type MapItemValueProps = Typeforge.Flatten<
    Types.BaseMapProps & {
        Value: any,
        Writable: boolean,
        TrySetValue: Types.TrySetValue<any>?,
        Redrawable: boolean,
        HoverState: Fusion.Value<boolean>?,
        FocusState: Fusion.Value<boolean>?
    }
>

local function MapItemValue(scope: Fusion.Scope, props: MapItemValueProps)
    local rowCount, rowIdx = props.RowCount, props.RowIdx
    local variant = props.Variant
    local value = props.Value

    local valueVariant: ValueVariants.ValueVariantFn<any> =
        (ValueVariants :: any)[typeof(value)] or
        DefaultValueVariant

    local theme = GetThemeForScope(scope)
    local bgColor = theme:GetBg(scope, variant)
    local rowHeight =
        ComputeAdd(scope, theme:GetHeight(scope, "Lg"), - 2)
    local innerCornerRadius =
        ComputeAdd(scope, theme:GetCornerRadius(scope, "Md"), - 1)

    local topLeftRadius, topRightRadius, bottomLeftRadius, bottomRightRadius =
        CalculateRowCornerRadii(
            scope,
            "Right",
            rowCount,
            rowIdx,
            props.Redrawable,
            innerCornerRadius
        )

    local border: Fusion.Child? = nil
    local focusRing: Fusion.Child? = nil
    local onFocusChanged: ((isFocused: boolean) -> ())? = nil
    local interactionProps: { [any]: any } = {}

    if props.Writable then
        local isHoverState = props.HoverState :: Fusion.Value<boolean>
        local isFocusState = props.FocusState :: Fusion.Value<boolean>
        local strokeColorModifier =
            CalcColorModifier(scope, isHoverState, isFocusState, "Stroke")
        local strokeColor =
            theme:GetBg(scope, GetNextVariant(variant), strokeColorModifier)
        local accentColor =
            theme:GetAccent(scope, "Primary", strokeColorModifier)

        local tweenStrokeColor = Tween<<Color3>>(
            scope,
            Computed(scope, function(use, scope): Color3
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

        local tweenStrokeTransparency = Tween<<number>>(
            scope,
            Computed(scope, function(use, scope): number
                local shouldShow =
                    use<<boolean>>(isHoverState) or
                    use<<boolean>>(isFocusState)

                return if shouldShow then 0 else 1
            end),
            TweenInfo.new(
                .18, Enum.EasingStyle.Exponential, Enum.EasingDirection.InOut
            )
        )

        border = Supercorner.new(scope, {
            BackgroundTransparency = 1,
            StrokeColor = tweenStrokeColor,
            StrokeTransparency = tweenStrokeTransparency,
            StrokeThickness = 1,
            Size = UDim2.new(1, 2, 1, 2),
            TopLeftRadius = topLeftRadius,
            TopRightRadius = topRightRadius,
            BottomLeftRadius = bottomLeftRadius,
            BottomRightRadius = bottomRightRadius,
            MaxCornerRadius =
                if props.Redrawable then innerCornerRadius else nil,
            Redrawable = props.Redrawable,
            Position = UDim2.fromScale(.5, .5),
            AnchorPoint = Vector2.new(.5, .5)
        })

        focusRing = FocusRing(scope, {
            IsFocus = isFocusState,
            CullWhenHidden = true,
            BaseSize = UDim2.new(1, 2, 1, 2),
            TopLeftRadius = Peek<<number>>(topLeftRadius),
            TopRightRadius = Peek<<number>>(topRightRadius),
            BottomLeftRadius = Peek<<number>>(bottomLeftRadius),
            BottomRightRadius = Peek<<number>>(bottomRightRadius)
        })

        local pendingFocusState = false
        local focusUpdateScheduled = false

        onFocusChanged = function(isFocused: boolean)
            pendingFocusState = isFocused
            if focusUpdateScheduled then return end

            -- A virtualized row can receive focus while Fusion is mounting it.
            -- Defer the state write to avoid mutating the graph mid-evaluation.
            focusUpdateScheduled = true
            task.defer(function()
                focusUpdateScheduled = false
                if Peek<<boolean>>(isFocusState) == pendingFocusState then
                    return
                end

                isFocusState:set(pendingFocusState)
            end)
        end

        interactionProps = {
            [OnEvent "MouseEnter"] = function() isHoverState:set(true) end,
            [OnEvent "MouseLeave"] = function() isHoverState:set(false) end
        }
    end

    return Supercorner.new(scope, CombineProps({
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

        RootChildren = {
            border :: any,
            focusRing
        },

        [Children] = {
            valueVariant(scope, {
                Value = value,
                Writable = props.Writable,
                TrySetValue = props.TrySetValue,
                OnFocusChanged = onFocusChanged
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
    }, interactionProps))
end

return MapItemValue
