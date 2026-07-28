--!strict

local Packages =
    script.Parent.Parent.Parent.Parent.Parent.Parent.Parent.Parent.Parent.packages
local Lexuau = require(Packages.lexuau)

local MathExpressionLexer =
    require(script.Parent.Parent.mathExpression.lexer)
type LexerState = MathExpressionLexer.State

type PatternConfig = Lexuau.PatternConfig<LexerState>
type Patterns = { [string]: PatternConfig }

local function CreateDelimitedNumbersLexer(
    extraPatterns: Patterns?
): Lexuau.Lexer<LexerState>
    local lexer: Lexuau.Lexer<LexerState>?
    local patterns: Patterns = {
        expression = {
            pattern = "[^,{}#\\s]+",
            callback = function(value: string, state: LexerState)
                state.ReturnLexer = lexer
                return value, MathExpressionLexer
            end
        },
        comma = ","
    }

    if extraPatterns ~= nil then
        for name, pattern in extraPatterns do
            patterns[name] = pattern
        end
    end

    lexer = Lexuau.new<<LexerState>>({
        skip = "[ \t\n\r\f]+",
        init_state = function(): LexerState
            return {
                ReturnLexer = nil
            }
        end,
        patterns = patterns
    })

    return lexer :: Lexuau.Lexer<LexerState>
end

return CreateDelimitedNumbersLexer
