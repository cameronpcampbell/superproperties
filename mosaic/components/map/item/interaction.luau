--!strict

local Packages = script.Parent.Parent.Parent.Parent.Parent
local Supercorner = require(Packages.supercorner)

local Fusion = require(Packages.fusion)
local Computed, OnEvent, Peek, Tween =
    Fusion.Computed, Fusion.OnEvent, Fusion.peek, Fusion.Tween

local Utils = script.Parent.Parent.Parent.Parent.utils
local FusionUtils = require(Utils.fusionUtils)
local Oktween = FusionUtils.Oktween

local ThemeUtils = require(Utils.themeUtils)
local GetThemeForScope, GetNextVariant, CalcColorModifier =
    ThemeUtils.GetThemeForScope, ThemeUtils.GetNextVariant,
    ThemeUtils.CalcColorModifier

local Components = script.Parent.Parent.Parent
local FocusRing = require(Components.focusRing)

local FocusTransitionTweenInfo = require(script.Parent.value.focusTransitionTweenInfo)
local HoverTweenInfo = require(script.Parent.hoverTweenInfo)

local FocusElevationReleasePadding = 1 / 30

export type Props = {
    Variant: ThemeUtils.BgVariantLayer,
    Writable: boolean,
    Redrawable: boolean,
    TopLeftRadius: Fusion.UsedAs<number>,
    TopRightRadius: Fusion.UsedAs<number>,
    BottomLeftRadius: Fusion.UsedAs<number>,
    BottomRightRadius: Fusion.UsedAs<number>,
    MaxCornerRadius: Fusion.UsedAs<number>,
    HoverState: Fusion.Value<boolean>?,
    FocusState: Fusion.Value<boolean>?,
    FocusElevationState: Fusion.Value<boolean>?,
    FocusRingAlphaState: Fusion.Value<number>?
}

export type Result = {
    RootChildren: { Fusion.Child },
    InteractionProps: { [any]: any },
    OnFocusChanged: ((isFocused: boolean) -> ())?
}

local function CreateMapItemInteraction(
    scope: Fusion.Scope,
    props: Props
): Result
    local interactionProps: { [any]: any } = {}

    if props.HoverState then
        local hoverState = props.HoverState
        interactionProps = {
            [OnEvent "MouseEnter"] = function() hoverState:set(true) end,
            [OnEvent "MouseLeave"] = function() hoverState:set(false) end
        }
    end

    if not props.Writable then
        return {
            RootChildren = {},
            InteractionProps = interactionProps,
            OnFocusChanged = nil
        }
    end

    local isHoverState = props.HoverState :: Fusion.Value<boolean>
    local isFocusState = props.FocusState :: Fusion.Value<boolean>
    local isFocusElevationState =
        props.FocusElevationState :: Fusion.Value<boolean>
    local focusRingAlphaState =
        props.FocusRingAlphaState :: Fusion.Value<number>
    local theme = GetThemeForScope(scope)
    local strokeColorModifier: Fusion.UsedAs<ThemeUtils.ThemeColorModifier?> =
        CalcColorModifier(scope, isHoverState, isFocusState, "Stroke")
    local strokeColor = theme:GetBg(
        scope,
        GetNextVariant(scope, props.Variant),
        strokeColorModifier
    )
    local accentColor =
        theme:GetAccent(scope, "Primary", strokeColorModifier)

    local tweenStrokeColor = Oktween(
        scope,
        Computed(scope, function(use): Color3
            return
                if use<<boolean>>(isFocusState) then
                    use<<Color3>>(accentColor)
                else
                    use<<Color3>>(strokeColor)
        end),
        HoverTweenInfo
    )

    local tweenStrokeTransparency = Tween<<number>>(
        scope,
        Computed(scope, function(use): number
            local shouldShow =
                use<<boolean>>(isHoverState) or
                use<<boolean>>(isFocusState)

            return if shouldShow then 0 else 1
        end),
        HoverTweenInfo
    )

    local border = Supercorner.new(scope, {
        BackgroundTransparency = 1,
        StrokeColor = tweenStrokeColor,
        StrokeTransparency = tweenStrokeTransparency,
        StrokeThickness = 1,
        Size = UDim2.new(1, 2, 1, 2),
        TopLeftRadius = props.TopLeftRadius,
        TopRightRadius = props.TopRightRadius,
        BottomLeftRadius = props.BottomLeftRadius,
        BottomRightRadius = props.BottomRightRadius,
        MaxCornerRadius =
            if props.Redrawable then props.MaxCornerRadius else nil,
        Redrawable = props.Redrawable,
        Position = UDim2.fromScale(.5, .5),
        AnchorPoint = Vector2.new(.5, .5)
    })

    local focusRing = FocusRing(scope, {
        IsFocus = isFocusState,
        AlphaOut = focusRingAlphaState,
        CullWhenHidden = true,
        TransitionTweenInfo = FocusTransitionTweenInfo,
        BaseSize = UDim2.new(1, 2, 1, 2),
        TopLeftRadius = props.TopLeftRadius,
        TopRightRadius = props.TopRightRadius,
        BottomLeftRadius = props.BottomLeftRadius,
        BottomRightRadius = props.BottomRightRadius,
        MaxCornerRadius =
            if props.Redrawable then props.MaxCornerRadius else nil,
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

    local function onFocusChanged(isFocused: boolean)
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
                    if not Peek<<boolean>>(isFocusElevationState) then return end

                    isFocusElevationState:set(false)
                end
            )
        end)
    end

    return {
        RootChildren = { border, focusRing },
        InteractionProps = interactionProps,
        OnFocusChanged = onFocusChanged
    }
end

return CreateMapItemInteraction
