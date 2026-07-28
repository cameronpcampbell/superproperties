--!strict

local MathExpressionLexer = require(script.Parent.lexer)

type Token = {
    Kind: string?,
    Value: string
}

type Parser = {
    Tokens: { Token },
    Position: number
}

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

local function Tokenize(text: string): { Token }
    local tokens = {}

    for value, kind in MathExpressionLexer.lex(text) do
        table.insert(tokens, {
            Kind = kind,
            Value = value
        })
    end

    return tokens
end

local ParseAdditive: (Parser) -> (number?, string?)
local ParseUnary: (Parser) -> (number?, string?)

local function ParsePrimary(parser: Parser): (number?, string?)
    local token = Peek(parser)

    if token ~= nil and token.Kind == "number" then
        Advance(parser)

        local normalizedValue = string.gsub(token.Value, "_", "")
        local value = tonumber(normalizedValue)
        if value == nil then
            return nil,
                `Invalid number {string.format("%q", token.Value)}.`
        end

        return value, nil
    end

    if token ~= nil and token.Kind == "leftBracket" then
        Advance(parser)

        local value, parseError = ParseAdditive(parser)
        if value == nil then
            return nil, parseError
        end

        local rightBracket = Peek(parser)
        if rightBracket == nil or rightBracket.Kind ~= "rightBracket" then
            return nil,
                `Expected ")" after the bracketed expression, found {DescribeToken(rightBracket)}.`
        end

        Advance(parser)
        return value, nil
    end

    return nil,
        `Expected a number or "(", found {DescribeToken(token)}.`
end

local function ParsePower(parser: Parser): (number?, string?)
    local left, parseError = ParsePrimary(parser)
    if left == nil then
        return nil, parseError
    end

    local token = Peek(parser)
    if token == nil or token.Kind ~= "pow" then
        return left, nil
    end

    Advance(parser)

    local right
    right, parseError = ParseUnary(parser)
    if right == nil then
        return nil, parseError
    end

    return left ^ right, nil
end

ParseUnary = function(parser: Parser): (number?, string?)
    local token = Peek(parser)
    if
        token == nil
        or (token.Kind ~= "add" and token.Kind ~= "subtract")
    then
        return ParsePower(parser)
    end

    Advance(parser)

    local value, parseError = ParseUnary(parser)
    if value == nil then
        return nil, parseError
    end

    return if token.Kind == "subtract" then -value else value, nil
end

local function ParseMultiplicative(parser: Parser): (number?, string?)
    local left, parseError = ParseUnary(parser)
    if left == nil then
        return nil, parseError
    end

    while true do
        local token = Peek(parser)
        if
            token == nil
            or (
                token.Kind ~= "multiply"
                and token.Kind ~= "divide"
                and token.Kind ~= "mod"
            )
        then
            break
        end

        Advance(parser)

        local right
        right, parseError = ParseUnary(parser)
        if right == nil then
            return nil, parseError
        end

        if token.Kind == "multiply" then
            left *= right
        elseif token.Kind == "divide" then
            left /= right
        else
            left = left % right
        end
    end

    return left, nil
end

ParseAdditive = function(parser: Parser): (number?, string?)
    local left, parseError = ParseMultiplicative(parser)
    if left == nil then
        return nil, parseError
    end

    while true do
        local token = Peek(parser)
        if
            token == nil
            or (token.Kind ~= "add" and token.Kind ~= "subtract")
        then
            break
        end

        Advance(parser)

        local right
        right, parseError = ParseMultiplicative(parser)
        if right == nil then
            return nil, parseError
        end

        if token.Kind == "add" then
            left += right
        else
            left -= right
        end
    end

    return left, nil
end

local function ParseMathExpression(text: string): (number?, string?)
    local parser: Parser = {
        Tokens = Tokenize(text),
        Position = 1
    }

    local value, parseError = ParseAdditive(parser)
    if value == nil then
        return nil, parseError
    end

    local trailingToken = Peek(parser)
    if trailingToken ~= nil then
        return nil,
            `Expected end of expression, found {DescribeToken(trailingToken)}.`
    end

    return value, nil
end

return ParseMathExpression
