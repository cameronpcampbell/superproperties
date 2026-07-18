--!strict

local Packages =
    script.Parent.Parent.Parent.Parent.Parent.Parent.Parent.Parent.Parent.packages
local Lexuau = require(Packages.lexuau)

local CreateDelimitedNumbersLexer =
    require(script.Parent.Parent.utils.createDelimitedNumbersLexer)

local UDim2Lexer: Lexuau.Lexer<nil>?
local UDimBodyLexer: Lexuau.Lexer<nil>?

local udim2Patterns: { [string]: Lexuau.PatternConfig<nil> } = {
    leftBrace = {
        pattern = "{",
        callback = function(value: string, _state: nil)
            return value, UDimBodyLexer :: Lexuau.Lexer<nil>
        end
    }
}

UDim2Lexer = CreateDelimitedNumbersLexer(udim2Patterns)

local udimBodyPatterns: { [string]: Lexuau.PatternConfig<nil> } = {
    rightBrace = {
        pattern = "}",
        callback = function(value: string, _state: nil)
            return value, UDim2Lexer :: Lexuau.Lexer<nil>
        end
    }
}

UDimBodyLexer = CreateDelimitedNumbersLexer(udimBodyPatterns)

return UDim2Lexer :: Lexuau.Lexer<nil>
