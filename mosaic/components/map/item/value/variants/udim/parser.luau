--!strict

local DelimitedNumbersLexer =
    require(script.Parent.Parent.utils.delimitedNumbersLexer)

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
    local sign = 1
    local token = Peek(parser)

    if token ~= nil and token.Kind == "sign" then
        Advance(parser)
        if token.Value == "-" then
            sign = -1
        end

        local numberToken = Peek(parser)
        if numberToken == nil or numberToken.Kind ~= "number" then
            return nil,
                `Expected a number after {string.format("%q", token.Value)} for the {componentName} component, found {DescribeToken(numberToken)}.`
        end

        token = numberToken
    end

    if token == nil or token.Kind ~= "number" then
        return nil,
            `Expected the {componentName} component, found {DescribeToken(token)}.`
    end

    Advance(parser)

    local normalizedValue = string.gsub(token.Value, "_", "")
    local value = tonumber(normalizedValue)
    if value == nil then
        return nil,
            `Invalid number {string.format("%q", token.Value)} for the {componentName} component.`
    end

    return sign * value, nil
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
