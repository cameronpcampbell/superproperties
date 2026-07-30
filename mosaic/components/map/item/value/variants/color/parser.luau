--!strict

local Packages =
    script.Parent.Parent.Parent.Parent.Parent.Parent.Parent.Parent.Parent.packages
local Lexuau = require(Packages.lexuau)

local CreateDelimitedNumbersLexer =
    require(script.Parent.Parent.utils.createDelimitedNumbersLexer)
local NormalizeCommaDelimitedTokens =
    require(script.Parent.Parent.utils.normalizeCommaDelimitedTokens)
local MathExpressionLexer =
    require(script.Parent.Parent.mathExpression.lexer)
type LexerState = MathExpressionLexer.State

local ParseMathExpression =
    require(script.Parent.Parent.mathExpression.parser)

type Token = NormalizeCommaDelimitedTokens.Token

type Parser = {
    Tokens: { Token },
    Position: number
}

local HexLexer = Lexuau.new<<LexerState>>({
    skip = "[ \t\n\r\f]+",
    init_state = function(): LexerState
        return {
            ReturnLexer = nil
        }
    end,

    patterns = {
        hex = "[\\da-fA-F]+"
    }
})

local colorPatterns: {
    [string]: Lexuau.PatternConfig<LexerState>
} = {
    hash = {
        pattern = "#",
        callback = function(value: string, _state: LexerState)
            return value, HexLexer
        end
    }
}

local ColorLexer = CreateDelimitedNumbersLexer(colorPatterns)

local function DescribeToken(token: Token?): string
    if token == nil then
        return "end of input"
    end

    local quotedValue = string.format("%q", token.Value)
    if token.Kind == nil then
        return `invalid character {quotedValue}`
    end

    return `{token.Kind} {quotedValue}`
end

local function Peek(parser: Parser): Token?
    return parser.Tokens[parser.Position]
end

local function Advance(parser: Parser): Token?
    local token = Peek(parser)
    if token ~= nil then
        parser.Position += 1
    end

    return token
end

local function ParseComponent(
    parser: Parser,
    componentName: string
): (number?, string?)
    local expressionParts: { string } = {}

    while true do
        local token = Peek(parser)
        if
            token == nil
            or token.Kind == "comma"
            or token.Kind == "rightBrace"
        then
            break
        end

        table.insert(expressionParts, token.Value)
        Advance(parser)
    end

    local value, parseError =
        ParseMathExpression(table.concat(expressionParts, " "))
    if value == nil then
        return nil,
            `Invalid math expression for the {componentName} component: {parseError or "Invalid expression."}`
    end

    return value, nil
end

local function ParseComma(
    parser: Parser,
    previousComponentName: string
): (boolean, string?)
    local token = Peek(parser)
    if token == nil or token.Kind ~= "comma" then
        return false,
            `Expected "," after the {previousComponentName} component, found {DescribeToken(token)}.`
    end

    Advance(parser)
    return true, nil
end

local function NormalizeComponent(
    component: number,
    multiplier: number,
    componentName: string
): (number?, string?)
    local normalizedValue = math.max(component * multiplier, 0)

    if normalizedValue > 255 then
        return nil,
            `The {componentName} component must normalize to a value between 0 and 255.`
    end

    return normalizedValue, nil
end

local function Tokenize(text: string): { Token }
    local tokens = {}

    for value, kind in ColorLexer.lex(text) do
        table.insert(tokens, {
            Kind = kind,
            Value = value
        })
    end

    return tokens
end

local function NormalizeHex(hex: string): string
    local digitCount = #hex

    if digitCount < 3 then
        hex ..= string.rep("0", 3 - digitCount)
    elseif digitCount < 6 then
        hex = string.sub(hex, 1, 3)
    elseif digitCount > 6 then
        hex = string.sub(hex, 1, 6)
    end

    if #hex == 3 then
        local red = string.sub(hex, 1, 1)
        local green = string.sub(hex, 2, 2)
        local blue = string.sub(hex, 3, 3)
        hex = `{red}{red}{green}{green}{blue}{blue}`
    end

    return string.upper(hex)
end

local function ParseHex(parser: Parser): (Color3?, string?)
    Advance(parser)

    local token = Peek(parser)
    if token == nil or token.Kind ~= "hex" then
        return nil,
            `Expected hexadecimal digits after "#", found {DescribeToken(token)}.`
    end

    Advance(parser)

    local trailingToken = Peek(parser)
    if trailingToken ~= nil then
        return nil,
            `Expected end of input after the hexadecimal color, found {DescribeToken(trailingToken)}.`
    end

    return Color3.fromHex(NormalizeHex(token.Value)), nil
end

local function ParseRgb(parser: Parser): (Color3?, string?)
    local redComponent, parseError = ParseComponent(parser, "red")
    if redComponent == nil then
        return nil, parseError
    end

    local success
    success, parseError = ParseComma(parser, "red")
    if not success then
        return nil, parseError
    end

    local greenComponent
    greenComponent, parseError = ParseComponent(parser, "green")
    if greenComponent == nil then
        return nil, parseError
    end

    success, parseError = ParseComma(parser, "green")
    if not success then
        return nil, parseError
    end

    local blueComponent
    blueComponent, parseError = ParseComponent(parser, "blue")
    if blueComponent == nil then
        return nil, parseError
    end

    local trailingToken = Peek(parser)
    if trailingToken ~= nil then
        return nil,
            `Expected end of input after the blue component, found {DescribeToken(trailingToken)}.`
    end

    local componentsAreNormalized =
        redComponent >= 0 and redComponent <= 1 and
        greenComponent >= 0 and greenComponent <= 1 and
        blueComponent >= 0 and blueComponent <= 1
    local multiplier = if componentsAreNormalized then 255 else 1

    local red, green, blue

    red, parseError = NormalizeComponent(redComponent, multiplier, "red")
    if red == nil then return nil, parseError end

    green, parseError = NormalizeComponent(greenComponent, multiplier, "green")
    if green == nil then return nil, parseError end

    blue, parseError = NormalizeComponent(blueComponent, multiplier, "blue")
    if blue == nil then return nil, parseError end

    return Color3.fromRGB(red, green, blue), nil
end

local function ParseColor(text: string): (Color3?, string?)
    local tokens = Tokenize(text)
    local firstToken = tokens[1]
    if firstToken ~= nil and firstToken.Kind == "hash" then
        return ParseHex({
            Tokens = tokens,
            Position = 1
        })
    end

    return ParseRgb({
        Tokens = NormalizeCommaDelimitedTokens(tokens),
        Position = 1
    })
end

return ParseColor
