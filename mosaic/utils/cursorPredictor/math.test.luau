--!strict

local Roblox = require("@lune/roblox")
local Vector2 = Roblox.Vector2

local CursorPredictionMath =
    require("./math")

local TestConfig = {
    HistoryWindow = 0.08,
    MaxSamples = 8,
    MaxHorizon = 0.05,
    MaxLead = 100,
    MaxSampleGap = 0.1,
    MinSpeed = 10,
    FullConfidenceSpeed = 100,
    MaxFitError = 4,
    MinConfidence = 0.5,
    DirectionResetDot = -0.25,
}

local function AssertNear(
    actual: number,
    expected: number,
    label: string,
    tolerance: number?
)
    local resolvedTolerance = tolerance or 0.0001
    assert(
        math.abs(actual - expected) < resolvedTolerance,
        `{label}: expected {expected}, got {actual}`
    )
end

local function AssertVectorNear(
    actual: Vector2,
    expected: Vector2,
    label: string,
    tolerance: number?
)
    AssertNear(actual.X, expected.X, `{label} X`, tolerance)
    AssertNear(actual.Y, expected.Y, `{label} Y`, tolerance)
end

local function AddSample(
    state: CursorPredictionMath.State,
    x: number,
    y: number,
    time: number,
    config: CursorPredictionMath.Config?
)
    CursorPredictionMath.Update(
        state,
        Vector2.new(x, y),
        time,
        config or TestConfig
    )
end

local emptyState = CursorPredictionMath.NewState()
assert(
    CursorPredictionMath.Predict(emptyState, 0, TestConfig) == nil,
    "a state without samples should not predict"
)
assert(
    CursorPredictionMath.IsSettled(emptyState, 0, TestConfig),
    "a state without samples should be settled"
)

local straightState = CursorPredictionMath.NewState()
AddSample(straightState, 0, 20, 1)
AddSample(straightState, 10, 20, 1.02)
AddSample(straightState, 20, 20, 1.04)

local straightPrediction =
    CursorPredictionMath.Predict(straightState, 1.04, TestConfig)
assert(straightPrediction, "straight motion should predict")
AssertVectorNear(
    straightPrediction.Position,
    Vector2.new(45, 20),
    "straight motion"
)
AssertNear(
    straightPrediction.Confidence,
    1,
    "straight motion confidence"
)

local laterPrediction =
    CursorPredictionMath.Predict(straightState, 1.06, TestConfig)
assert(laterPrediction, "an unexpired prediction should remain available")
AssertVectorNear(
    laterPrediction.Position,
    straightPrediction.Position,
    "prediction remains stable between samples"
)
AssertNear(laterPrediction.Horizon, 0.03, "remaining horizon")

local expiredPrediction =
    CursorPredictionMath.Predict(straightState, 1.091, TestConfig)
assert(expiredPrediction, "an expired state still returns actual position")
AssertVectorNear(
    expiredPrediction.Position,
    Vector2.new(20, 20),
    "expired prediction"
)
AssertNear(
    expiredPrediction.Confidence,
    0,
    "expired prediction confidence"
)
assert(
    CursorPredictionMath.IsSettled(straightState, 1.091, TestConfig),
    "prediction should settle after its adaptive horizon"
)

local ClampConfig = table.clone(TestConfig)
ClampConfig.MaxLead = 10
local clampedPrediction =
    CursorPredictionMath.Predict(straightState, 1.04, ClampConfig)
assert(clampedPrediction, "clamped motion should predict")
AssertVectorNear(
    clampedPrediction.Position,
    Vector2.new(30, 20),
    "maximum lead clamp"
)

local irregularState = CursorPredictionMath.NewState()
AddSample(irregularState, 0, 0, 2)
AddSample(irregularState, 5, 0, 2.01)
AddSample(irregularState, 20, 0, 2.04)
local irregularPrediction =
    CursorPredictionMath.Predict(irregularState, 2.04, TestConfig)
assert(irregularPrediction, "irregular motion should predict")
AssertNear(
    irregularPrediction.Velocity.X,
    500,
    "irregular timestamp velocity",
    0.001
)

local noisyStraightState = CursorPredictionMath.NewState()
AddSample(noisyStraightState, 0, 0, 2.5)
AddSample(noisyStraightState, 10, 0.5, 2.52)
AddSample(noisyStraightState, 20, -0.5, 2.54)
AddSample(noisyStraightState, 30, 0.5, 2.56)
local noisyStraightPrediction =
    CursorPredictionMath.Predict(
        noisyStraightState,
        2.56,
        TestConfig
    )
assert(
    noisyStraightPrediction,
    "noisy straight motion should return a result"
)
assert(
    noisyStraightPrediction.Confidence >= TestConfig.MinConfidence,
    "small perpendicular noise should keep prediction reliable"
)
assert(
    math.abs(noisyStraightPrediction.Position.Y) < 2,
    "the fitted trajectory should reject small perpendicular noise"
)

local jitterState = CursorPredictionMath.NewState()
AddSample(jitterState, 100, 100, 3)
AddSample(jitterState, 101, 100, 3.02)
AddSample(jitterState, 100, 101, 3.04)
AddSample(jitterState, 101, 100, 3.06)
local jitterPrediction =
    CursorPredictionMath.Predict(jitterState, 3.06, TestConfig)
assert(jitterPrediction, "jitter state should return actual position")
AssertNear(
    jitterPrediction.Confidence,
    0,
    "stationary jitter confidence"
)
AssertVectorNear(
    jitterPrediction.Position,
    Vector2.new(101, 100),
    "stationary jitter position"
)

local reversalState = CursorPredictionMath.NewState()
AddSample(reversalState, 0, 0, 4)
AddSample(reversalState, 10, 0, 4.02)
AddSample(reversalState, 20, 0, 4.04)
AddSample(reversalState, 10, 0, 4.06)
local reversalPrediction =
    CursorPredictionMath.Predict(reversalState, 4.06, TestConfig)
assert(reversalPrediction, "reversal state should return actual position")
AssertNear(
    reversalPrediction.Confidence,
    0,
    "direction reversal confidence"
)
AssertVectorNear(
    reversalPrediction.Position,
    Vector2.new(10, 0),
    "direction reversal position"
)

local constantState = CursorPredictionMath.NewState()
AddSample(constantState, 0, 0, 5)
AddSample(constantState, 20, 0, 5.02)
AddSample(constantState, 40, 0, 5.04)
local constantPrediction =
    CursorPredictionMath.Predict(constantState, 5.04, TestConfig)
assert(constantPrediction, "constant state should predict")

local brakingState = CursorPredictionMath.NewState()
AddSample(brakingState, 0, 0, 5)
AddSample(brakingState, 20, 0, 5.02)
AddSample(brakingState, 30, 0, 5.04)
local brakingPrediction =
    CursorPredictionMath.Predict(brakingState, 5.04, TestConfig)
assert(brakingPrediction, "braking state should return a result")
assert(
    brakingPrediction.Confidence < constantPrediction.Confidence,
    "deceleration should reduce confidence"
)

AddSample(brakingState, 100, 100, 6)
local resetPrediction =
    CursorPredictionMath.Predict(brakingState, 6, TestConfig)
assert(resetPrediction, "reset state should return actual position")
AssertNear(resetPrediction.Confidence, 0, "large gap confidence")
AssertVectorNear(
    resetPrediction.Position,
    Vector2.new(100, 100),
    "large sample gap reset"
)

local segmentHit = CursorPredictionMath.IntersectSegmentRect(
    Vector2.new(0, 10),
    Vector2.new(100, 10),
    Vector2.new(40, 0),
    Vector2.new(20, 20)
)
assert(segmentHit, "a segment crossing a rectangle should hit")
AssertNear(segmentHit.Fraction, 0.4, "segment hit fraction")
AssertVectorNear(
    segmentHit.Position,
    Vector2.new(40, 10),
    "segment hit position"
)

assert(
    CursorPredictionMath.IntersectSegmentRect(
        Vector2.new(0, 30),
        Vector2.new(100, 30),
        Vector2.new(40, 0),
        Vector2.new(20, 20)
    ) == nil,
    "a parallel segment outside a rectangle should miss"
)

local insideHit = CursorPredictionMath.IntersectSegmentRect(
    Vector2.new(50, 10),
    Vector2.new(100, 10),
    Vector2.new(40, 0),
    Vector2.new(20, 20)
)
assert(insideHit, "a segment starting inside should hit")
AssertNear(insideHit.Fraction, 0, "inside segment fraction")

assert(
    CursorPredictionMath.IsPointInRect(
        Vector2.new(10, 10),
        Vector2.new(10, 10),
        Vector2.new(20, 20)
    ),
    "top-left edge should be inside"
)
assert(
    not CursorPredictionMath.IsPointInRect(
        Vector2.new(30, 30),
        Vector2.new(10, 10),
        Vector2.new(20, 20)
    ),
    "bottom-right edge should be outside"
)
assert(
    not CursorPredictionMath.IsPointInRect(
        Vector2.zero,
        Vector2.zero,
        Vector2.zero
    ),
    "empty rectangles should not contain points"
)

print("cursorPredictionMath verification passed")
