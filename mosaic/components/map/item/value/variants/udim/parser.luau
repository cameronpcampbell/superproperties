--!strict

local DelimitedNumbersLexer =
    require(script.Parent.Parent.utils.delimitedNumbersLexer)
local ParseMathExpression =
    require(script.Parent.Parent.mathExpression.parser)

export type Components = {
    Scale: number,
    Offset: number
}

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

local function Tokenize(text: string): { Token }
    local tokens = {}

    for value, kind in DelimitedNumbersLexer.lex(text) do
        table.insert(tokens, {
            Kind = kind,
            Value = value
        })
    end

    return tokens
end

local function ParseUDim(text: string): (Components?, string?)
    local parser: Parser = {
        Tokens = Tokenize(text),
        Position = 1
    }

    local value, parseError = ParseComponent(parser, "scale or offset")
    if value == nil then
        return nil, parseError
    end

    if Peek(parser) == nil then
        if math.abs(value) <= 1 then
            return {
                Scale = value,
                Offset = 0
            }, nil
        end

        return {
            Scale = 0,
            Offset = value
        }, nil
    end

    local success
    success, parseError = ParseComma(parser, "scale")
    if not success then
        return nil, parseError
    end

    local offset
    offset, parseError = ParseComponent(parser, "offset")
    if offset == nil then
        return nil, parseError
    end

    local trailingToken = Peek(parser)
    if trailingToken ~= nil then
        return nil,
            `Expected end of input after the offset component, found {DescribeToken(trailingToken)}.`
    end

    return {
        Scale = value,
        Offset = offset
    }, nil
end

return ParseUDim
