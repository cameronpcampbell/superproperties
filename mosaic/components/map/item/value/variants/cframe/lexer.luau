--!strict

local Packages =
    script.Parent.Parent.Parent.Parent.Parent.Parent.Parent.Parent.Parent.packages
local Lexuau = require(Packages.lexuau)

local CreateDelimitedNumbersLexer =
    require(script.Parent.Parent.utils.createDelimitedNumbersLexer)
local MathExpressionLexer =
    require(script.Parent.Parent.mathExpression.lexer)
type LexerState = MathExpressionLexer.State

local cframePatterns: {
    [string]: Lexuau.PatternConfig<LexerState>
} = {
    leftBrace = "{",
    rightBrace = "}"
}

return CreateDelimitedNumbersLexer(cframePatterns)
