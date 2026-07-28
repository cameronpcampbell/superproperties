--!strict

local Packages =
    script.Parent.Parent.Parent.Parent.Parent.Parent.Parent.Parent.Parent.packages
local Lexuau = require(Packages.lexuau)

export type State = {
    ReturnLexer: Lexuau.Lexer<State>?
}

local function ReturnToConsumer(
    value: string,
    state: State
): (string, Lexuau.Lexer<State>?)
    return value, state.ReturnLexer
end

local MathExpressionLexer = Lexuau.new<<State>>({
    skip = "[ \t\n\r\f]+",
    init_state = function(): State
        return {
            ReturnLexer = nil
        }
    end,

    subpatterns = {
        numsect = "_*[\\d]+_*",
        decimal =
            "((?&numsect)+\\.(?&numsect)*|(?&numsect)+|\\.(?&numsect)+)",
        exponent = "[eE][+-]?(?&numsect)+",
        num = "(?&decimal)((?&exponent))?"
    },

    patterns = {
        number = "(?&num)",
        leftBracket = "\\(",
        rightBracket = "\\)",
        add = "\\+",
        subtract = "-",
        multiply = "\\*",
        divide = "/",
        pow = "\\^",
        mod = "%",

        comma = {
            pattern = ",",
            callback = ReturnToConsumer
        },
        rightBrace = {
            pattern = "}",
            callback = ReturnToConsumer
        }
    }
})

return MathExpressionLexer
