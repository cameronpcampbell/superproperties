--!strict
--!nolint LocalShadow

local Packages = script.Parent.Parent.Parent
local Supercorner = require(Packages.supercorner)

local Fusion = require(Packages.fusion)
local Computed, Observer, OnEvent, Peek, Spring, Value =
    Fusion.Computed, Fusion.Observer, Fusion.OnEvent,
    Fusion.peek, Fusion.Spring, Fusion.Value

local Utils = script.Parent.Parent.utils

local FusionUtils = require(Utils.fusionUtils)
local Component, CombineProps = FusionUtils.Component, FusionUtils.CombineProps

local ThemeUtils = require(Utils.themeUtils)
local GetThemeForScope = ThemeUtils.GetThemeForScope

local TableUtils = require(Utils.tableUtils)
local TableExtract = TableUtils.Extract

type HighlightGradientProps = {
    Enabled: Fusion.UsedAs<boolean>?,
    GradientTransparency: Fusion.UsedAs<number>?,
    DefaultRotation: Fusion.UsedAs<number>?,
    CenterLockRadius: number?,
    CenterReleaseRadius: number?,
    FollowSpringSpeed: Fusion.UsedAs<number>?,
    ReturnSpringSpeed: Fusion.UsedAs<number>?,
    SpringDamping: Fusion.UsedAs<number>?,
    [Fusion.SpecialKey]: any
}

local GradientName = "MosaicHighlightGradient"

local function GetNearestEquivalentAngle(
    angle: number,
    reference: number
): number
    return angle + math.round((reference - angle) / 360) * 360
end

local function WrapAngleDelta(delta: number): number
    return (delta + 180) % 360 - 180
end

local function GetPointerRotation(
    root: GuiObject,
    x: number,
    y: number
): (number?, number?)
    local halfSize = root.AbsoluteSize / 2
    if halfSize.X <= 0 or halfSize.Y <= 0 then return nil end

    local center = root.AbsolutePosition + halfSize
    local direction = Vector2.new(
        (x - center.X) / halfSize.X,
        (y - center.Y) / halfSize.Y
    )
    local radius = direction.Magnitude
    if radius < 0.0001 then return nil, radius end

    -- Extend the centre-to-cursor ray until it reaches the rectangular edge.
    -- This keeps the virtual cursor on the perimeter without choosing one of
    -- four discrete edges.
    local edgeScale = 1 / math.max(
        math.abs(direction.X),
        math.abs(direction.Y)
    )
    local edgeDirection = direction * edgeScale

    -- The first gradient keypoint is the highlight, so point the beginning
    -- of the gradient axis towards the cursor's projected edge position.
    return math.deg(math.atan2(edgeDirection.Y, edgeDirection.X)) + 180,
        radius
end

return Component<<HighlightGradientProps>>(function(scope, props)
    local props, enabled = TableExtract(props, "Enabled", true)
    local props, gradientTransparency =
        TableExtract(props, "GradientTransparency", 0.78)
    local props, defaultRotation =
        TableExtract(props, "DefaultRotation", 90)
    local props, centerLockRadius =
        TableExtract(props, "CenterLockRadius", 0.3)
    local props, centerReleaseRadius =
        TableExtract(props, "CenterReleaseRadius", 0.45)
    local props, followSpringSpeed =
        TableExtract(props, "FollowSpringSpeed", 18)
    local props, returnSpringSpeed =
        TableExtract(props, "ReturnSpringSpeed", 10)
    local props, springDamping =
        TableExtract(props, "SpringDamping", 1)
    local props, onMouseEnter = TableExtract(props, OnEvent "MouseEnter")
    local props, onMouseMoved = TableExtract(props, OnEvent "MouseMoved")
    local props, onMouseLeave = TableExtract(props, OnEvent "MouseLeave")

    local isEnabled = Computed(scope, function(use): boolean
        return use<<boolean>>(enabled)
    end)
    local isFollowingPointer = Value(scope, false)
    local rotationGoal = Value(scope, Peek<<number>>(defaultRotation))

    local rotationSpringSpeed = Computed(scope, function(use): number
        return
            if use<<boolean>>(isFollowingPointer) then
                use<<number>>(followSpringSpeed)
            else use<<number>>(returnSpringSpeed)
    end)

    local animatedRotation = Spring<<number>>(
        scope,
        rotationGoal,
        rotationSpringSpeed,
        springDamping
    )

    local theme = GetThemeForScope(scope)
    local highlightGradient =
        theme:HighlightGradient(scope, gradientTransparency)
    highlightGradient.Name = GradientName
    highlightGradient.Type = Enum.GradientType.Linear
    highlightGradient.Offset = Vector2.zero

    local root: GuiObject? = nil
    local unwrappedGoal = Peek<<number>>(defaultRotation)
    local previousRawRotation: number? = nil
    local lockedTurnSign: number? = nil
    local lastTurnSign = 1

    local function ApplyRotationTo(instance: Instance, rotation: number)
        if not instance:IsA("UIGradient") then return end
        if instance.Name ~= GradientName then return end

        instance.Type = Enum.GradientType.Linear
        instance.Offset = Vector2.zero
        instance.Rotation = rotation
    end

    local function ApplyRotation(rotation: number)
        local currentRoot = root
        if not currentRoot then return end

        for _, descendant in currentRoot:GetDescendants() do
            ApplyRotationTo(descendant, rotation)
        end
    end

    local function ResetRotation()
        previousRawRotation = nil
        lockedTurnSign = nil
        lastTurnSign = 1
        isFollowingPointer:set(false)
        local returnGoal = GetNearestEquivalentAngle(
            Peek<<number>>(defaultRotation),
            Peek<<number>>(animatedRotation)
        )
        unwrappedGoal = returnGoal
        rotationGoal:set(returnGoal)
    end

    local function FollowPointer(x: number, y: number)
        if not Peek<<boolean>>(isEnabled) then return end

        local currentRoot = root
        if not currentRoot then return end

        local pointerRotation, radius = GetPointerRotation(
            currentRoot,
            x,
            y
        )
        if not pointerRotation or not radius then return end

        local lockRadius = math.max(centerLockRadius, 0)
        local releaseRadius = math.max(centerReleaseRadius, lockRadius)

        if radius <= lockRadius and not lockedTurnSign then
            lockedTurnSign = lastTurnSign
        elseif radius >= releaseRadius then
            lockedTurnSign = nil
        end

        local previousRotation = previousRawRotation
        if previousRotation and not lockedTurnSign then
            local rawStep = WrapAngleDelta(
                pointerRotation - previousRotation
            )
            if math.abs(rawStep) > 0.5 then
                lastTurnSign = math.sign(rawStep)
            end
        end
        previousRawRotation = pointerRotation

        local delta = WrapAngleDelta(pointerRotation - unwrappedGoal)
        if lockedTurnSign and math.abs(delta) > 90 then
            delta = math.abs(delta) * lockedTurnSign
        end
        unwrappedGoal += delta

        isFollowingPointer:set(true)
        rotationGoal:set(unwrappedGoal)
    end

    Observer(scope, animatedRotation):onChange(function()
        ApplyRotation(Peek<<number>>(animatedRotation))
    end)

    Observer(scope, isEnabled):onChange(function()
        if Peek<<boolean>>(isEnabled) then return end

        ResetRotation()
    end)

    local createdRoot = Supercorner.new(scope :: any, CombineProps(props, {
        StrokeGradient = highlightGradient,

        [OnEvent "MouseEnter"] = function(x: number, y: number)
            FollowPointer(x, y)
            if onMouseEnter then onMouseEnter(x, y) end
        end,

        [OnEvent "MouseMoved"] = function(x: number, y: number)
            FollowPointer(x, y)
            if onMouseMoved then onMouseMoved(x, y) end
        end,

        [OnEvent "MouseLeave"] = function(x: number, y: number)
            ResetRotation()
            if onMouseLeave then onMouseLeave(x, y) end
        end,
    })) :: GuiObject
    root = createdRoot

    ApplyRotation(Peek<<number>>(animatedRotation))
    table.insert(scope, createdRoot.DescendantAdded:Connect(function(descendant)
        ApplyRotationTo(descendant, Peek<<number>>(animatedRotation))
    end))

    return createdRoot
end)
