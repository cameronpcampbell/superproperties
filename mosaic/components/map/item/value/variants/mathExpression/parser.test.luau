--!strict

local ParseMathExpression = require("./parser")

local Epsilon = 1e-9

local function AssertExpression(
    text: string,
    expected: number,
    label: string
)
    local actual, parseError = ParseMathExpression(text)
    assert(
        actual ~= nil,
        `{label}: expected a number, got {parseError or "an invalid expression"}`
    )
    assert(
        math.abs(actual - expected) <= Epsilon,
        `{label}: expected {expected}, got {actual}`
    )
end

local function AssertInvalid(text: string, label: string)
    local actual, parseError = ParseMathExpression(text)
    assert(
        actual == nil and parseError ~= nil,
        `{label}: expected an invalid expression`
    )
end

AssertExpression("42", 42, "sole number")
AssertExpression("1_000 + 2", 1002, "underscored number")
AssertExpression("1e3 / 4", 250, "scientific notation")
AssertExpression("2 + 3 * 4", 14, "multiplication precedence")
AssertExpression("(2 + 3) * 4", 20, "brackets")
AssertExpression("20 / 5 * 2", 8, "left associative multiplication")
AssertExpression("10 % 4", 2, "modulo")
AssertExpression("2 ^ 3 ^ 2", 512, "right associative power")
AssertExpression("-2 ^ 2", -4, "power before unary")
AssertExpression("(-2) ^ 2", 4, "bracketed unary")
AssertExpression("2 ^ -2", 0.25, "unary power operand")
AssertExpression("+2 + -3", -1, "unary signs")

AssertInvalid("", "empty input")
AssertInvalid("()", "empty brackets")
AssertInvalid("2 +", "missing operand")
AssertInvalid("(1 + 2", "missing right bracket")
AssertInvalid("1 2", "adjacent numbers")
AssertInvalid("1, 2", "comma")
AssertInvalid("hello", "invalid characters")

print("math expression parser verification passed")
