--!strict
--!nolint LocalShadow

local RunService = game:GetService("RunService")

local Packages = script.Parent.Parent.Parent

local Fusion = require(Packages.fusion)
local Computed, Observer, Peek, Tween, Value =
    Fusion.Computed, Fusion.Observer, Fusion.peek, Fusion.Tween, Fusion.Value

local Utils = script.Parent.Parent.utils

local FusionUtils = require(Utils.fusionUtils)
local CombineProps, ComposeTransparency, ConstructorComponent =
    FusionUtils.CombineProps, FusionUtils.ComposeTransparency,
    FusionUtils.ConstructorComponent

local TableUtils = require(Utils.tableUtils)
local TableExtract = TableUtils.Extract

local Fit = require(script.fit)

export type Props = {
    Position: Fusion.UsedAs<UDim2>?,
    AnchorPoint: Fusion.UsedAs<Vector2>?,
    Enabled: Fusion.UsedAs<boolean>?,
    StickToViewport: Fusion.UsedAs<boolean>?,
    Visible: Fusion.UsedAs<boolean>?,
    Transparency: Fusion.UsedAs<number>?,
    OutRenderVisible: Fusion.Value<boolean>?,
    OutTransitionTransparency: Fusion.Value<number>?,
    [any]: any
}

local TransitionOffset = 6
local TransitionTweenInfo = TweenInfo.new(
    .2,
    Enum.EasingStyle.Quint,
    Enum.EasingDirection.InOut
)

local function GetGuiParent(instance: Instance): GuiBase2d?
    local parent = instance.Parent

    return
        if parent and parent:IsA("GuiBase2d") then parent :: GuiBase2d
        else nil
end

local function GetViewport(
    instance: Instance
): (GuiBase2d?, { GuiObject })
    local ancestor = instance.Parent
    local clipAncestors: { GuiObject } = {}

    while ancestor do
        if ancestor:IsA("GuiObject") then
            table.insert(clipAncestors, ancestor)

            if ancestor.ClipsDescendants then
                return ancestor, clipAncestors
            end
        end

        if ancestor:IsA("LayerCollector") then
            return ancestor, clipAncestors
        end

        ancestor = ancestor.Parent
    end

    return nil, clipAncestors
end

local function EqualInstances<T>(left: { T }, right: { T }): boolean
    if #left ~= #right then return false end

    for idx, instance in left do
        if instance ~= right[idx] then return false end
    end

    return true
end

local function GetPositionOffsetScale(
    parent: GuiBase2d,
    viewport: GuiBase2d
): number
    local scale = 1
    local ancestor: Instance? = parent

    while ancestor do
        for _, child in ancestor:GetChildren() do
            if child:IsA("UIScale") then scale *= child.Scale end
        end

        if ancestor == viewport then break end
        ancestor = ancestor.Parent
    end

    return scale
end

return ConstructorComponent<<Props>>(function(scope, constructor, props)
    local props, preferredPosition =
        TableExtract(props, "Position", UDim2.fromScale(0, 0))
    local props, preferredAnchorPoint =
        TableExtract(props, "AnchorPoint", Vector2.zero)
    local props, enabled = TableExtract(props, "Enabled", true)
    local props, stickToViewport =
        TableExtract(props, "StickToViewport", false)
    local props, visible = TableExtract(props, "Visible", true)
    local props, transparency = TableExtract(props, "Transparency", 0)
    local props, outRenderVisible =
        TableExtract(props, "OutRenderVisible")
    local props, outTransitionTransparency =
        TableExtract(props, "OutTransitionTransparency")

    local effectivePreferredPosition = Computed(scope, function(use): UDim2
        return use<<UDim2>>(preferredPosition)
    end)
    local effectivePreferredAnchorPoint =
        Computed(scope, function(use): Vector2
            return use<<Vector2>>(preferredAnchorPoint)
        end)
    local effectiveEnabled = Computed(scope, function(use): boolean
        return use<<boolean>>(enabled)
    end)
    local effectiveStickToViewport = Computed(scope, function(use): boolean
        return use<<boolean>>(stickToViewport)
    end)
    local effectiveVisible = Computed(scope, function(use): boolean
        return use<<boolean>>(visible)
    end)
    local entranceReady = Value(
        scope,
        Peek<<boolean>>(effectiveVisible)
    )
    local transitionVisible = Computed(scope, function(use): boolean
        return
            use<<boolean>>(effectiveVisible)
            and use<<boolean>>(entranceReady)
    end)

    local renderedPosition =
        Value(scope, Peek<<UDim2>>(effectivePreferredPosition))
    local renderedAnchorPoint =
        Value(scope, Peek<<Vector2>>(effectivePreferredAnchorPoint))

    local transitionTransparency = Tween<<number>>(
        scope,
        Computed(scope, function(use): number
            return if use<<boolean>>(transitionVisible) then 0 else 1
        end),
        TransitionTweenInfo
    )
    local shouldRender = Computed(scope, function(use): boolean
        return
            use<<boolean>>(effectiveVisible)
            or use<<number>>(transitionTransparency) < .999
    end)
    local animatedPosition = Computed(scope, function(use): UDim2
        local position = use<<UDim2>>(renderedPosition)
        local anchorPoint = use<<Vector2>>(renderedAnchorPoint)
        local offsetDirection = if anchorPoint.Y > .5 then -1 else 1
        local offset =
            use<<number>>(transitionTransparency)
            * TransitionOffset
            * offsetDirection

        return UDim2.new(
            position.X.Scale,
            position.X.Offset,
            position.Y.Scale,
            position.Y.Offset + offset
        )
    end)
    local animatedTransparency = ComposeTransparency(
        scope,
        transparency,
        transitionTransparency
    )

    Observer(scope, shouldRender):onBind(function()
        if not outRenderVisible then return end

        local isRendering = Peek<<boolean>>(shouldRender)
        if Peek<<boolean>>(outRenderVisible) == isRendering then return end

        (outRenderVisible :: Fusion.Value<boolean>):set(isRendering)
    end)

    Observer(scope, transitionTransparency):onBind(function()
        if not outTransitionTransparency then return end

        local usedTransparency =
            Peek<<number>>(transitionTransparency)
        if
            Peek<<number>>(outTransitionTransparency)
                == usedTransparency
        then
            return
        end

        (outTransitionTransparency :: Fusion.Value<number>):set(usedTransparency)
    end)

    local target = constructor(scope, CombineProps({
        Position = animatedPosition,
        AnchorPoint = renderedAnchorPoint,
        Transparency = animatedTransparency,
        Visible = shouldRender
    }, props)) :: GuiObject

    local scopeAlive = true
    local placementQueued = false
    local openingRevision = 0
    local geometryRevision = 0
    local observedParent: GuiBase2d? = nil
    local observedViewport: GuiBase2d? = nil
    local observedClipAncestors: { GuiObject } = {}
    local geometryConnections: { RBXScriptConnection } = {}
    local QueuePlacement: () -> ()

    local function DisconnectGeometryConnections()
        for _, connection in geometryConnections do
            connection:Disconnect()
        end

        table.clear(geometryConnections)
    end

    local function SetPlacement(position: UDim2, anchorPoint: Vector2)
        if Peek<<UDim2>>(renderedPosition) ~= position then
            renderedPosition:set(position)
        end

        if Peek<<Vector2>>(renderedAnchorPoint) ~= anchorPoint then
            renderedAnchorPoint:set(anchorPoint)
        end
    end

    local function RefreshGeometryConnections()
        local nextParent = GetGuiParent(target)
        local nextViewport, nextClipAncestors = GetViewport(target)

        if nextParent == observedParent
            and nextViewport == observedViewport
            and EqualInstances(
                nextClipAncestors,
                observedClipAncestors
            )
        then
            return
        end

        DisconnectGeometryConnections()
        observedParent = nextParent
        observedViewport = nextViewport
        observedClipAncestors = nextClipAncestors

        local function ObserveGeometry(gui: GuiBase2d)
            table.insert(
                geometryConnections,
                gui:GetPropertyChangedSignal("AbsolutePosition")
                    :Connect(QueuePlacement)
            )
            table.insert(
                geometryConnections,
                gui:GetPropertyChangedSignal("AbsoluteSize")
                    :Connect(QueuePlacement)
            )
        end

        if nextParent then ObserveGeometry(nextParent) end
        if nextViewport and nextViewport ~= nextParent then
            ObserveGeometry(nextViewport)
        end

        for _, ancestor in nextClipAncestors do
            table.insert(
                geometryConnections,
                ancestor:GetPropertyChangedSignal("ClipsDescendants")
                    :Connect(QueuePlacement)
            )
        end
    end

    local function UpdatePlacement(): boolean
        RefreshGeometryConnections()

        local usedPreferredPosition =
            Peek<<UDim2>>(effectivePreferredPosition)
        local usedPreferredAnchorPoint =
            Peek<<Vector2>>(effectivePreferredAnchorPoint)

        if not Peek<<boolean>>(effectiveEnabled) then
            if not Peek<<boolean>>(effectiveVisible)
                and Peek<<boolean>>(shouldRender)
            then
                return false
            end

            SetPlacement(
                usedPreferredPosition,
                usedPreferredAnchorPoint
            )
            return true
        end

        local parent = observedParent
        local viewport = observedViewport
        local targetSize = target.AbsoluteSize

        if not parent
            or not viewport
            or targetSize.X <= 0
            or targetSize.Y <= 0
            or viewport.AbsoluteSize.X <= 0
            or viewport.AbsoluteSize.Y <= 0
        then
            SetPlacement(
                usedPreferredPosition,
                usedPreferredAnchorPoint
            )
            return false
        end

        local positionOffsetScale =
            GetPositionOffsetScale(parent, viewport)
        if positionOffsetScale <= 0 then
            SetPlacement(
                usedPreferredPosition,
                usedPreferredAnchorPoint
            )
            return false
        end

        local placement = Fit({
            PreferredPosition = usedPreferredPosition,
            PreferredAnchorPoint = usedPreferredAnchorPoint,
            ParentPosition = parent.AbsolutePosition,
            ParentSize = parent.AbsoluteSize,
            TargetSize = targetSize,
            ViewportPosition = viewport.AbsolutePosition,
            ViewportSize = viewport.AbsoluteSize,
            PositionOffsetScale = positionOffsetScale,
            StickToViewport =
                Peek<<boolean>>(effectiveStickToViewport)
        })

        SetPlacement(placement.Position, placement.AnchorPoint)
        return true
    end

    local function QueueEntranceReadyConfirmation()
        if Peek<<boolean>>(entranceReady) then return end
        if not Peek<<boolean>>(effectiveVisible) then return end

        local usedOpeningRevision = openingRevision
        local usedGeometryRevision = geometryRevision

        task.spawn(function()
            -- GUI layouts and AutomaticSize settle on frame boundaries rather
            -- than task scheduler turns. Require two unchanged frames before
            -- beginning the visible transition.
            RunService.Heartbeat:Wait()
            if not scopeAlive then return end
            if usedOpeningRevision ~= openingRevision then return end
            if usedGeometryRevision ~= geometryRevision then return end
            if not Peek<<boolean>>(effectiveVisible) then return end

            RunService.Heartbeat:Wait()
            if not scopeAlive then return end
            if usedOpeningRevision ~= openingRevision then return end
            if usedGeometryRevision ~= geometryRevision then return end
            if not Peek<<boolean>>(effectiveVisible) then return end
            if not UpdatePlacement() then return end
            if usedGeometryRevision ~= geometryRevision then return end

            entranceReady:set(true)
        end)
    end

    QueuePlacement = function()
        geometryRevision += 1
        if placementQueued then return end
        placementQueued = true

        task.defer(function()
            placementQueued = false
            if not scopeAlive then return end

            if UpdatePlacement() then
                QueueEntranceReadyConfirmation()
            end
        end)
    end

    table.insert(scope, function()
        scopeAlive = false
        openingRevision += 1
        DisconnectGeometryConnections()
    end)

    table.insert(
        scope,
        target:GetPropertyChangedSignal("AbsoluteSize")
            :Connect(QueuePlacement)
    )
    table.insert(scope, target.AncestryChanged:Connect(QueuePlacement))

    Observer(scope, effectivePreferredPosition):onChange(QueuePlacement)
    Observer(scope, effectivePreferredAnchorPoint):onChange(QueuePlacement)
    Observer(scope, effectiveEnabled):onBind(QueuePlacement)
    Observer(scope, effectiveStickToViewport):onChange(QueuePlacement)
    Observer(scope, effectiveVisible):onChange(function()
        openingRevision += 1
        entranceReady:set(false)

        if Peek<<boolean>>(effectiveVisible) then
            QueuePlacement()
        end
    end)
    Observer(scope, shouldRender):onChange(QueuePlacement)

    return target
end)
