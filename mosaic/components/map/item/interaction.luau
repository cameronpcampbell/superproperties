--!strict

local Packages = script.Parent.Parent.Parent.Parent.Parent
local Supercorner = require(Packages.supercorner)

local Fusion = require(Packages.fusion)
local Computed, OnEvent, Peek, Tween, Value =
    Fusion.Computed, Fusion.OnEvent, Fusion.peek, Fusion.Tween, Fusion.Value

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
local ZIndices = require(script.Parent.Parent.zIndices)

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
    OnFocusChanged: ((
        isFocused: boolean,
        parserFailed: boolean?
    ) -> ())?
}

local function CreateMapItemInteraction(
    scope: Fusion.Scope,
    props: Props
): Result
    local interactionProps: { [any]: any } = {}

    if props.HoverState then
        local hoverState = props.HoverState
        interactionProps[OnEvent "MouseEnter"] =
            function() hoverState:set(true) end
        interactionProps[OnEvent "MouseLeave"] =
            function() hoverState:set(false) end
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
    local focusRingVariantState =
        Value<<ThemeUtils.AccentVariant>>(scope, "Primary")

    interactionProps.ZIndex = Computed(
        scope,
        function(use: Fusion.Use): number
            local focusRingAlpha =
                use<<number>>(focusRingAlphaState)

            if focusRingAlpha >= ZIndices.FocusRingActiveAlphaThreshold then
                return ZIndices.Focus
            end
            if use<<boolean>>(isFocusElevationState) then
                return ZIndices.DisappearingFocus
            end
            return ZIndices.Default
        end
    )

    local theme = GetThemeForScope(scope)
    local strokeColorModifier: Fusion.UsedAs<ThemeUtils.ThemeColorModifier?> =
        CalcColorModifier(scope, isHoverState, isFocusState, "Stroke")
    local strokeColor = theme:GetBg(
        scope,
        GetNextVariant(scope, props.Variant),
        strokeColorModifier
    )
    local accentColor = theme:GetAccent(
        scope,
        focusRingVariantState,
        strokeColorModifier
    )

    local tweenStrokeColor = Oktween(
        scope,
        Computed(scope, function(use): Color3
            local focusRingVariant =
                use<<ThemeUtils.AccentVariant>>(focusRingVariantState)

            return
                if
                    use<<boolean>>(isFocusState)
                    or focusRingVariant == "Destructive"
                then
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

    -- Keep focus-driven visuals mounted. Returning them through reactive
    -- children can make Fusion's [Children] traversal re-enter a busy state
    -- when a TextBox receives focus.
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
        Variant = focusRingVariantState,
        IsFocus = isFocusState,
        CullWhenHidden = false,
        AlphaOut = focusRingAlphaState,
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
    local pendingFocusRingVariant: ThemeUtils.AccentVariant = "Primary"
    local focusUpdateScheduled = false
    local focusRevision = 0
    local focusStateAlive = true

    table.insert(scope, function()
        focusStateAlive = false
        focusRevision += 1
    end)

    local function onFocusChanged(
        isFocused: boolean,
        parserFailed: boolean?
    )
        pendingFocusState = isFocused
        pendingFocusRingVariant =
            if isFocused and parserFailed
            then "Destructive"
            else "Primary"
        focusRevision += 1
        if focusUpdateScheduled then return end

        -- A virtualized row can receive focus while Fusion is mounting it.
        -- Defer the state write to avoid mutating the graph mid-evaluation.
        focusUpdateScheduled = true
        task.defer(function()
            focusUpdateScheduled = false
            if not focusStateAlive then return end

            local nextFocusState = pendingFocusState
            local nextFocusRingVariant = pendingFocusRingVariant
            local updateRevision = focusRevision

            if
                Peek<<ThemeUtils.AccentVariant>>(focusRingVariantState)
                    ~= nextFocusRingVariant
            then
                focusRingVariantState:set(nextFocusRingVariant)
            end

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
