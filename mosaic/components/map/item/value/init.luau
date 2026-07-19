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
local Arrow = require(script.Parent.Parent.arrow)

local ValueVariants = require(script.variants)
local DefaultValueVariant = ValueVariants.Default
local FocusTransitionTweenInfo = require(script.focusTransitionTweenInfo)

type MapItemValueProps = Typeforge.Flatten<
    Types.BaseMapProps & {
        Value: any,
        Writable: boolean,
        TrySetValue: Types.TrySetValue<any>?,
        Side: "Right" | "Both",
        CollapsedState: Fusion.Value<boolean>?,
        Redrawable: boolean,
        HoverState: Fusion.Value<boolean>?,
        FocusState: Fusion.Value<boolean>?,
        FocusElevationState: Fusion.Value<boolean>?,
        FocusRingAlphaState: Fusion.Value<number>?,
        RightChildren: Fusion.Child?
    }
>

local FocusElevationReleasePadding = 1 / 30

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
            props.Side,
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
        local isFocusElevationState =
            props.FocusElevationState :: Fusion.Value<boolean>
        local focusRingAlphaState =
            props.FocusRingAlphaState :: Fusion.Value<number>
        local strokeColorModifier =
            CalcColorModifier(scope, isHoverState, isFocusState, "Stroke")
        local strokeColor =
            theme:GetBg(scope, GetNextVariant(scope, variant), strokeColorModifier)
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
            AlphaOut = focusRingAlphaState,
            CullWhenHidden = true,
            TransitionTweenInfo = FocusTransitionTweenInfo,
            BaseSize = UDim2.new(1, 2, 1, 2),
            TopLeftRadius = topLeftRadius,
            TopRightRadius = topRightRadius,
            BottomLeftRadius = bottomLeftRadius,
            BottomRightRadius = bottomRightRadius,
            MaxCornerRadius =
                if props.Redrawable then innerCornerRadius else nil,
            Redrawable = props.Redrawable
        })

        local pendingFocusState = false
        local focusUpdateScheduled = false
        local focusRevision = 0
        local focusStateAlive = true

        table.insert(scope, function()
            focusStateAlive = false
            focusRevision += 1
        end)

        onFocusChanged = function(isFocused: boolean)
            pendingFocusState = isFocused
            focusRevision += 1
            if focusUpdateScheduled then return end

            -- A virtualized row can receive focus while Fusion is mounting it.
            -- Defer the state write to avoid mutating the graph mid-evaluation.
            focusUpdateScheduled = true
            task.defer(function()
                focusUpdateScheduled = false
                if not focusStateAlive then return end

                local nextFocusState = pendingFocusState
                local updateRevision = focusRevision

                if nextFocusState then
                    if not Peek<<boolean>>(isFocusElevationState) then
                        isFocusElevationState:set(true)
                    end

                    if not Peek<<boolean>>(isFocusState) then
                        isFocusState:set(true)
                    end
                    return
                end

                if Peek<<boolean>>(isFocusState) then
                    isFocusState:set(false)
                end

                task.delay(
                    FocusTransitionTweenInfo.Time + FocusElevationReleasePadding,
                    function()
                        if not focusStateAlive then return end
                        if updateRevision ~= focusRevision then return end
                        if Peek<<boolean>>(isFocusState) then return end
                        if not Peek<<boolean>>(isFocusElevationState) then
                            return
                        end

                        isFocusElevationState:set(false)
                    end
                )
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
            if props.CollapsedState then Arrow(scope, {
                CollapsedState = props.CollapsedState,
                Variant = if props.Writable then "Primary" else "Secondary",
                Thin = true,
                LayoutOrder = -1
            }) else nil,

            valueVariant(scope, {
                Value = value,
                Writable = props.Writable,
                TrySetValue = props.TrySetValue,
                OnFocusChanged = onFocusChanged,
                FocusState = props.FocusState
            }),

            props.RightChildren,

            New(scope, "UIListLayout") {
                Padding = UDim.new(0, 6),
                FillDirection = Enum.FillDirection.Horizontal,
                VerticalAlignment = Enum.VerticalAlignment.Center,
                SortOrder = Enum.SortOrder.LayoutOrder
            }
        }
    }, interactionProps))
end

return MapItemValue
