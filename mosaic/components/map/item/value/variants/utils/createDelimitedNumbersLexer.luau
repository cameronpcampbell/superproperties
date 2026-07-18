--!strict

local Packages =
    script.Parent.Parent.Parent.Parent.Parent.Parent.Parent.Parent.Parent.packages
local Lexuau = require(Packages.lexuau)

type PatternConfig = Lexuau.PatternConfig<nil>
type Patterns = { [string]: PatternConfig }

local function CreateDelimitedNumbersLexer(
    extraPatterns: Patterns?
): Lexuau.Lexer<nil>
    local patterns: Patterns = {
        number = "(?&num)",
        comma = ",",
        sign = "[+-]"
    }

    if extraPatterns ~= nil then
        for name, pattern in extraPatterns do
            patterns[name] = pattern
        end
    end

    return Lexuau.new<<nil>>({
        skip = "[ \t\n\r\f]+",
        init_state = function()
            return nil
        end,

        subpatterns = {
            numsect = "_*[\\d]+_*",
            num = "((?&numsect)+\\.)?(?&numsect)+|\\.(?&numsect)"
        },

        patterns = patterns
    })
end

return CreateDelimitedNumbersLexer
