--!strict

export type Config = {
    read HistoryWindow: number,
    read MaxSamples: number,
    read MaxHorizon: number,
    read MaxLead: number,
    read MaxSampleGap: number,
    read MinSpeed: number,
    read FullConfidenceSpeed: number,
    read MaxFitError: number,
    read MinConfidence: number,
    read DirectionResetDot: number,
}

export type Sample = {
    Position: Vector2,
    Time: number,
}

export type State = {
    Samples: { Sample },
    Actual: Vector2?,
    Velocity: Vector2?,
    Confidence: number,
    SampledAt: number,
}

export type Prediction = {
    Position: Vector2,
    Velocity: Vector2,
    Confidence: number,
    Horizon: number,
}

export type SegmentHit = {
    Position: Vector2,
    Fraction: number,
}

local DEFAULT_CONFIG: Config = table.freeze({
    HistoryWindow = 0.075,
    MaxSamples = 8,
    MaxHorizon = 0.05,
    MaxLead = 64,
    MaxSampleGap = 0.1,
    MinSpeed = 20,
    FullConfidenceSpeed = 250,
    MaxFitError = 6,
    MinConfidence = 0.55,
    DirectionResetDot = -0.25,
})

-- Deliberately unrealistic. Keep this available for visually verifying that
-- prediction is connected without making it the behaviour users receive.
local DEBUG_OVERPREDICTION_CONFIG: Config = table.freeze({
    HistoryWindow = 0.075,
    MaxSamples = 8,
    MaxHorizon = 2,
    MaxLead = 800,
    MaxSampleGap = 0.1,
    MinSpeed = 20,
    FullConfidenceSpeed = 250,
    MaxFitError = 6,
    MinConfidence = 0.55,
    DirectionResetDot = -0.25,
})

local EPSILON = 1e-6

local function NewState(): State
    return {
        Samples = {},
        Actual = nil,
        Velocity = nil,
        Confidence = 0,
        SampledAt = 0,
    }
end

local function Reset(
    state: State,
    actual: Vector2,
    now: number
)
    table.clear(state.Samples)
    table.insert(state.Samples, {
        Position = actual,
        Time = now,
    })
    state.Actual = actual
    state.Velocity = actual * 0
    state.Confidence = 0
    state.SampledAt = now
end

local function CalculateMotion(
    state: State,
    config: Config
)
    local samples = state.Samples
    local sampleCount = #samples
    if sampleCount < 3 then
        state.Velocity = samples[1].Position * 0
        state.Confidence = 0
        return
    end

    local historyWindow = math.max(config.HistoryWindow, EPSILON)
    local latestTime = samples[sampleCount].Time
    local totalWeight = 0
    local weightedTime = 0
    local weightedPosition = samples[1].Position * 0

    for _, sample in samples do
        local age = math.max(0, latestTime - sample.Time)
        local recency = 1 - math.clamp(age / historyWindow, 0, 1)
        local weight = 1 + recency * 2

        totalWeight += weight
        weightedTime += sample.Time * weight
        weightedPosition += sample.Position * weight
    end

    if totalWeight <= EPSILON then
        state.Velocity = samples[1].Position * 0
        state.Confidence = 0
        return
    end

    local meanTime = weightedTime / totalWeight
    local meanPosition = weightedPosition / totalWeight
    local timeVariance = 0
    local positionCovariance = samples[1].Position * 0

    for _, sample in samples do
        local age = math.max(0, latestTime - sample.Time)
        local recency = 1 - math.clamp(age / historyWindow, 0, 1)
        local weight = 1 + recency * 2
        local deltaTime = sample.Time - meanTime

        timeVariance += weight * deltaTime * deltaTime
        positionCovariance +=
            (sample.Position - meanPosition) * (weight * deltaTime)
    end

    if timeVariance <= EPSILON then
        state.Velocity = samples[1].Position * 0
        state.Confidence = 0
        return
    end

    local velocity = positionCovariance / timeVariance
    local speed = velocity.Magnitude
    state.Velocity = velocity

    local fitErrorSquared = 0
    local directionWeight = 0
    local directionAlignment = 0
    local velocityDirection =
        if speed > EPSILON then
            velocity / speed
        else
            samples[1].Position * 0

    for index, sample in samples do
        local age = math.max(0, latestTime - sample.Time)
        local recency = 1 - math.clamp(age / historyWindow, 0, 1)
        local weight = 1 + recency * 2
        local fittedPosition =
            meanPosition + velocity * (sample.Time - meanTime)
        local residual = sample.Position - fittedPosition
        fitErrorSquared += weight * residual:Dot(residual)

        if index > 1 then
            local previous = samples[index - 1]
            local segment = sample.Position - previous.Position
            local segmentMagnitude = segment.Magnitude
            if segmentMagnitude > EPSILON and speed > EPSILON then
                directionAlignment +=
                    weight
                    * math.max(
                        0,
                        (segment / segmentMagnitude):Dot(velocityDirection)
                    )
                directionWeight += weight
            end
        end
    end

    local fitError =
        math.sqrt(fitErrorSquared / math.max(totalWeight, EPSILON))
    local maxFitError = math.max(config.MaxFitError, 0)
    local fitConfidence =
        if maxFitError <= EPSILON then
            if fitError <= EPSILON then 1 else 0
        else
            1 - math.clamp(fitError / maxFitError, 0, 1)

    local directionConfidence =
        if directionWeight > EPSILON then
            directionAlignment / directionWeight
        else
            0

    local oldestTime = samples[1].Time
    local coverageTarget =
        math.max(math.min(historyWindow * 0.5, 0.04), EPSILON)
    local coverageConfidence =
        math.clamp((latestTime - oldestTime) / coverageTarget, 0, 1)

    local minSpeed = math.max(config.MinSpeed, 0)
    local fullConfidenceSpeed =
        math.max(config.FullConfidenceSpeed, minSpeed)
    local speedConfidence =
        if fullConfidenceSpeed <= minSpeed + EPSILON then
            if speed >= fullConfidenceSpeed then 1 else 0
        else
            math.clamp(
                (speed - minSpeed)
                    / (fullConfidenceSpeed - minSpeed),
                0,
                1
            )

    local brakingConfidence = 1
    local newest = samples[sampleCount]
    local previous = samples[sampleCount - 1]
    local recentDeltaTime = newest.Time - previous.Time
    if recentDeltaTime > EPSILON and speed > minSpeed then
        local recentVelocity =
            (newest.Position - previous.Position) / recentDeltaTime
        local recentSpeed = recentVelocity.Magnitude
        if recentVelocity:Dot(velocity) > 0 and recentSpeed < speed then
            brakingConfidence =
                math.clamp(recentSpeed / speed, 0, 1)
        end
    end

    state.Confidence = math.clamp(
        coverageConfidence
            * speedConfidence
            * fitConfidence
            * directionConfidence
            * brakingConfidence,
        0,
        1
    )
end

local function Update(
    state: State,
    actual: Vector2,
    now: number,
    config: Config?
)
    local resolvedConfig = config or DEFAULT_CONFIG
    local previousActual = state.Actual
    local deltaTime = now - state.SampledAt

    if not previousActual
        or deltaTime < 0
        or deltaTime > resolvedConfig.MaxSampleGap
    then
        Reset(state, actual, now)
        return
    end

    if deltaTime <= EPSILON then
        local latest = state.Samples[#state.Samples]
        if latest then
            latest.Position = actual
            latest.Time = now
        end
        state.Actual = actual
        state.SampledAt = now
        CalculateMotion(state, resolvedConfig)
        return
    end

    local sampleVelocity = (actual - previousActual) / deltaTime
    local previousVelocity =
        state.Velocity or sampleVelocity * 0
    if sampleVelocity.Magnitude >= resolvedConfig.MinSpeed
        and previousVelocity.Magnitude >= resolvedConfig.MinSpeed
        and sampleVelocity.Unit:Dot(previousVelocity.Unit)
            <= resolvedConfig.DirectionResetDot
    then
        local previousSample = state.Samples[#state.Samples]
        table.clear(state.Samples)
        if previousSample then
            table.insert(state.Samples, previousSample)
        end
    end

    table.insert(state.Samples, {
        Position = actual,
        Time = now,
    })

    local historyWindow = math.max(resolvedConfig.HistoryWindow, 0)
    while #state.Samples > 1
        and now - state.Samples[1].Time > historyWindow
    do
        table.remove(state.Samples, 1)
    end

    local maxSamples =
        math.max(2, math.floor(resolvedConfig.MaxSamples))
    while #state.Samples > maxSamples do
        table.remove(state.Samples, 1)
    end

    state.Actual = actual
    state.SampledAt = now
    CalculateMotion(state, resolvedConfig)
end

local function Predict(
    state: State,
    now: number,
    config: Config?
): Prediction?
    local actual = state.Actual
    if not actual then return nil end

    local resolvedConfig = config or DEFAULT_CONFIG
    local sampleAge = math.max(0, now - state.SampledAt)
    local predictionHorizon =
        math.max(0, resolvedConfig.MaxHorizon)
        * state.Confidence
    local remainingHorizon =
        math.max(0, predictionHorizon - sampleAge)

    if remainingHorizon <= 0 then
        return {
            Position = actual,
            Velocity = state.Velocity or actual * 0,
            Confidence = 0,
            Horizon = 0,
        }
    end

    local velocity = state.Velocity or actual * 0
    local offset = velocity * predictionHorizon
    local offsetMagnitude = offset.Magnitude
    local maxLead = math.max(resolvedConfig.MaxLead, 0)

    if offsetMagnitude > maxLead and offsetMagnitude > 0 then
        offset *= maxLead / offsetMagnitude
    end

    return {
        Position = actual + offset,
        Velocity = velocity,
        Confidence = state.Confidence,
        Horizon = remainingHorizon,
    }
end

local function IsSettled(
    state: State,
    now: number,
    config: Config?
): boolean
    if not state.Actual then return true end

    local resolvedConfig = config or DEFAULT_CONFIG
    local predictionHorizon =
        math.max(0, resolvedConfig.MaxHorizon)
        * state.Confidence
    return now - state.SampledAt >= predictionHorizon
end

local function IsPointInRect(
    point: Vector2,
    position: Vector2,
    size: Vector2
): boolean
    return
        size.X > 0
        and size.Y > 0
        and point.X >= position.X
        and point.Y >= position.Y
        and point.X < position.X + size.X
        and point.Y < position.Y + size.Y
end

local function IntersectSegmentRect(
    from: Vector2,
    to: Vector2,
    position: Vector2,
    size: Vector2
): SegmentHit?
    if size.X <= 0 or size.Y <= 0 then return nil end

    local delta = to - from
    local minimum = position
    local maximum = position + size
    local minimumFraction = 0
    local maximumFraction = 1

    local function ClipAxis(
        origin: number,
        direction: number,
        axisMinimum: number,
        axisMaximum: number
    ): boolean
        if math.abs(direction) <= EPSILON then
            return
                origin >= axisMinimum
                and origin <= axisMaximum
        end

        local first =
            (axisMinimum - origin) / direction
        local second =
            (axisMaximum - origin) / direction
        if first > second then
            first, second = second, first
        end

        minimumFraction = math.max(minimumFraction, first)
        maximumFraction = math.min(maximumFraction, second)
        return minimumFraction <= maximumFraction
    end

    if not ClipAxis(from.X, delta.X, minimum.X, maximum.X)
        or not ClipAxis(from.Y, delta.Y, minimum.Y, maximum.Y)
        or maximumFraction < 0
        or minimumFraction > 1
    then
        return nil
    end

    local fraction = math.clamp(minimumFraction, 0, 1)
    return {
        Position = from + delta * fraction,
        Fraction = fraction,
    }
end

return {
    DefaultConfig = DEFAULT_CONFIG,
    DebugOverpredictionConfig = DEBUG_OVERPREDICTION_CONFIG,
    NewState = NewState,
    Reset = Reset,
    Update = Update,
    Predict = Predict,
    IsSettled = IsSettled,
    IsPointInRect = IsPointInRect,
    IntersectSegmentRect = IntersectSegmentRect,
}
