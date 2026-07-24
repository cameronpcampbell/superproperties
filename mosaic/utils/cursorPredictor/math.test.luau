--!strict

local Roblox = require("@lune/roblox")
local Vector2 = Roblox.Vector2

local CursorPredictionMath =
    require("./math")

local TestConfig: CursorPredictionMath.Config = {
    Horizon = 0.02,
    MaxLead = 10,
    MaxSampleGap = 0.1,
    SmoothingTime = 0,
}

local function AssertNear(
    actual: number,
    expected: number,
    label: string
)
    assert(
        math.abs(actual - expected) < 0.0001,
        `{label}: expected {expected}, got {actual}`
    )
end

local function AssertVectorNear(
    actual: Vector2?,
    expected: Vector2,
    label: string
)
    assert(actual, `{label}: expected a position`)
    AssertNear(actual.X, expected.X, `{label} X`)
    AssertNear(actual.Y, expected.Y, `{label} Y`)
end

local state = CursorPredictionMath.NewState()
assert(
    CursorPredictionMath.Predict(state, 0, TestConfig) == nil,
    "a state without samples should not predict"
)
assert(
    CursorPredictionMath.IsSettled(state, 0, TestConfig),
    "a state without samples should be settled"
)

CursorPredictionMath.Update(
    state,
    Vector2.new(10, 20),
    1,
    TestConfig
)
AssertVectorNear(
    CursorPredictionMath.Predict(state, 1, TestConfig),
    Vector2.new(10, 20),
    "first sample"
)

CursorPredictionMath.Update(
    state,
    Vector2.new(20, 20),
    1.01,
    TestConfig
)
AssertVectorNear(
    CursorPredictionMath.Predict(state, 1.01, TestConfig),
    Vector2.new(30, 20),
    "maximum lead clamp"
)
AssertVectorNear(
    CursorPredictionMath.Predict(state, 1.02, TestConfig),
    Vector2.new(30, 20),
    "partially settled prediction"
)
AssertVectorNear(
    CursorPredictionMath.Predict(state, 1.03, TestConfig),
    Vector2.new(20, 20),
    "settled prediction"
)
assert(
    CursorPredictionMath.IsSettled(state, 1.03, TestConfig),
    "prediction should settle after its horizon"
)

CursorPredictionMath.Update(
    state,
    Vector2.new(19, 20),
    1.04,
    TestConfig
)
AssertVectorNear(
    CursorPredictionMath.Predict(state, 1.04, TestConfig),
    Vector2.new(18.333333, 20),
    "direction reversal"
)

CursorPredictionMath.Update(
    state,
    Vector2.new(100, 100),
    2,
    TestConfig
)
AssertVectorNear(
    CursorPredictionMath.Predict(state, 2, TestConfig),
    Vector2.new(100, 100),
    "large sample gap reset"
)

CursorPredictionMath.Reset(
    state,
    Vector2.new(3, 4),
    3
)
AssertVectorNear(
    CursorPredictionMath.Predict(state, 3, TestConfig),
    Vector2.new(3, 4),
    "explicit source reset"
)

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
