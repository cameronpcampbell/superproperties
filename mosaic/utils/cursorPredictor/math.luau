--!strict

export type Config = {
    Horizon: number,
    MaxLead: number,
    MaxSampleGap: number,
    SmoothingTime: number,
}

export type State = {
    Actual: Vector2?,
    Velocity: Vector2?,
    SampledAt: number,
}

local DEFAULT_CONFIG: Config = table.freeze({
    Horizon = 1 / 60,
    MaxLead = 18,
    MaxSampleGap = 0.1,
    SmoothingTime = 0.025,
})

local function NewState(): State
    return {
        Actual = nil,
        Velocity = nil,
        SampledAt = 0,
    }
end

local function Reset(
    state: State,
    actual: Vector2,
    now: number
)
    state.Actual = actual
    state.Velocity = actual * 0
    state.SampledAt = now
end

local function Update(
    state: State,
    actual: Vector2,
    now: number,
    config: Config?
)
    local resolvedConfig = config or DEFAULT_CONFIG
    local previous = state.Actual
    local deltaTime = now - state.SampledAt

    if not previous
        or deltaTime <= 0
        or deltaTime > resolvedConfig.MaxSampleGap
    then
        Reset(state, actual, now)
        return
    end

    local rawVelocity = (actual - previous) / deltaTime
    local currentVelocity = state.Velocity or rawVelocity
    local smoothingTime = math.max(resolvedConfig.SmoothingTime, 0)
    local alpha =
        if smoothingTime == 0 then 1
        else 1 - math.exp(-deltaTime / smoothingTime)

    state.Actual = actual
    state.Velocity = currentVelocity:Lerp(rawVelocity, alpha)
    state.SampledAt = now
end

local function Predict(
    state: State,
    now: number,
    config: Config?
): Vector2?
    local actual = state.Actual
    if not actual then return nil end

    local resolvedConfig = config or DEFAULT_CONFIG
    local sampleAge = math.max(0, now - state.SampledAt)
    local remainingLead =
        math.max(0, resolvedConfig.Horizon - sampleAge)
    local offset = (state.Velocity or actual * 0) * remainingLead
    local offsetMagnitude = offset.Magnitude
    local maxLead = math.max(resolvedConfig.MaxLead, 0)

    if offsetMagnitude > maxLead and offsetMagnitude > 0 then
        offset *= maxLead / offsetMagnitude
    end

    return actual + offset
end

local function IsSettled(
    state: State,
    now: number,
    config: Config?
): boolean
    if not state.Actual then return true end

    local resolvedConfig = config or DEFAULT_CONFIG
    return now - state.SampledAt >= resolvedConfig.Horizon
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

return {
    DefaultConfig = DEFAULT_CONFIG,
    NewState = NewState,
    Reset = Reset,
    Update = Update,
    Predict = Predict,
    IsSettled = IsSettled,
    IsPointInRect = IsPointInRect,
}
