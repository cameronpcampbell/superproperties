--!strict

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Packages = script.Parent.Parent.Parent.Parent
local Fusion = require(Packages.fusion)

local ColorSpace = require(script.Parent.Parent.colorSpace)
local Oklab = ColorSpace.Oklab

local Observer, Peek, Value = Fusion.Observer, Fusion.peek, Fusion.Value

local DEFAULT_TWEEN_INFO = TweenInfo.new()
local REBASE_EPSILON = 1e-6

local function GetTweenDuration(tweenInfo: TweenInfo): number
    if tweenInfo.RepeatCount <= -1 then return math.huge end

    local duration = tweenInfo.DelayTime + tweenInfo.Time
    if tweenInfo.Reverses then duration += tweenInfo.Time end

    return duration * (tweenInfo.RepeatCount + 1)
end

local function GetTweenRatio(
    tweenInfo: TweenInfo,
    elapsed: number
): number
    local delay = tweenInfo.DelayTime
    local duration = tweenInfo.Time
    local cycleDuration = delay + duration
    if tweenInfo.Reverses then cycleDuration += duration end

    if elapsed == math.huge then return 1 end
    if
        tweenInfo.RepeatCount > -1 and
        elapsed >= cycleDuration * (tweenInfo.RepeatCount + 1)
    then
        return 1
    end
    if cycleDuration == 0 then return 1 end

    local cycleTime = elapsed % cycleDuration
    if cycleTime <= delay then return 0 end

    local progress = (cycleTime - delay) / duration
    if progress > 1 then progress = 2 - progress end

    return TweenService:GetValue(
        progress,
        tweenInfo.EasingStyle,
        tweenInfo.EasingDirection
    )
end

local function RebaseOrigin(
    current: Color3,
    target: Color3,
    ratio: number
)
    local currentL, currentA, currentB = Oklab.From(current):Components()
    local targetL, targetA, targetB = Oklab.From(target):Components()
    local remaining = 1 - ratio

    return Oklab.new(
        (currentL - targetL * ratio) / remaining,
        (currentA - targetA * ratio) / remaining,
        (currentB - targetB * ratio) / remaining
    )
end

local function Oktween(
    scope: Fusion.Scope,
    goal: Fusion.UsedAs<Color3>,
    tweenInfo: TweenInfo?
): Fusion.StateObject<Color3>
    local resolvedTweenInfo = tweenInfo or DEFAULT_TWEEN_INFO
    local initialColor = Peek<<Color3>>(goal)
    local output = Value<<Color3>>(scope, initialColor)

    local activeGoal = initialColor
    local origin = Oklab.From(initialColor)
    local previousRatio = 0
    local startedAt = 0
    local totalDuration = GetTweenDuration(resolvedTweenInfo)
    local heartbeatConnection: RBXScriptConnection? = nil
    local destroyed = false

    local function Stop()
        if not heartbeatConnection then return end

        heartbeatConnection:Disconnect()
        heartbeatConnection = nil
    end

    local function Step()
        local nextGoal = Peek<<Color3>>(goal)
        local goalChanged = nextGoal ~= activeGoal

        if goalChanged then
            if math.abs(1 - previousRatio) > REBASE_EPSILON then
                origin = RebaseOrigin(
                    Peek<<Color3>>(output),
                    nextGoal,
                    previousRatio
                )
            else
                origin = Oklab.From(Peek<<Color3>>(output))
            end

            activeGoal = nextGoal
        end

        local elapsed = os.clock() - startedAt
        local ratio = GetTweenRatio(resolvedTweenInfo, elapsed)

        output:set(
            origin:Lerp(Oklab.From(activeGoal), ratio):ToColor3()
        )
        previousRatio = ratio

        if elapsed >= totalDuration then
            output:set(activeGoal)
            previousRatio = 1

            if not goalChanged then Stop() end
        end
    end

    local function Start()
        if destroyed or heartbeatConnection then return end

        activeGoal = Peek<<Color3>>(goal)
        origin = Oklab.From(Peek<<Color3>>(output))
        previousRatio = 0
        startedAt = os.clock()
        totalDuration = GetTweenDuration(resolvedTweenInfo)
        heartbeatConnection = RunService.Heartbeat:Connect(Step)
    end

    local stopObserving = Observer(scope, goal):onChange(Start)
    table.insert(scope, function()
        destroyed = true
        stopObserving()
        Stop()
    end)

    return output
end

return Oktween
