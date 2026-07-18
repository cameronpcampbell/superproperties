--!strict

local CFrameLexer = require(script.Parent.lexer)

type VectorComponents = {
    X: number,
    Y: number,
    Z: number
}

export type Components = {
    Position: VectorComponents,
    Orientation: VectorComponents?
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

local function ExpectToken(
    parser: Parser,
    expectedKind: string,
    expectation: string
): (Token?, string?)
    local token = Peek(parser)
    if token == nil or token.Kind ~= expectedKind then
        return nil, `Expected {expectation}, found {DescribeToken(token)}.`
    end

    Advance(parser)
    return token, nil
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

local function ParseVectorComponents(
    parser: Parser,
    vectorName: string
): (VectorComponents?, string?)
    local x, parseError = ParseComponent(parser, `{vectorName} x`)
    if x == nil then
        return nil, parseError
    end

    local success
    success, parseError = ParseComma(parser, `{vectorName} x`)
    if not success then
        return nil, parseError
    end

    local y
    y, parseError = ParseComponent(parser, `{vectorName} y`)
    if y == nil then
        return nil, parseError
    end

    success, parseError = ParseComma(parser, `{vectorName} y`)
    if not success then
        return nil, parseError
    end

    local z
    z, parseError = ParseComponent(parser, `{vectorName} z`)
    if z == nil then
        return nil, parseError
    end

    return {
        X = x,
        Y = y,
        Z = z
    }, nil
end

local function ParseBracedVector(
    parser: Parser,
    vectorName: string
): (VectorComponents?, string?)
    local _, parseError =
        ExpectToken(parser, "leftBrace", `a left brace before the {vectorName}`)
    if parseError ~= nil then
        return nil, parseError
    end

    local components
    components, parseError = ParseVectorComponents(parser, vectorName)
    if components == nil then
        return nil, parseError
    end

    _, parseError =
        ExpectToken(parser, "rightBrace", `a right brace after the {vectorName}`)
    if parseError ~= nil then
        return nil, parseError
    end

    return components, nil
end

local function ParseFlatCFrame(parser: Parser): (Components?, string?)
    local position, parseError = ParseVectorComponents(parser, "position")
    if position == nil then
        return nil, parseError
    end

    local trailingToken = Peek(parser)
    if trailingToken ~= nil then
        return nil,
            `Expected end of input after the position, found {DescribeToken(trailingToken)}.`
    end

    return {
        Position = position
    }, nil
end

local function ParseBracedCFrame(parser: Parser): (Components?, string?)
    local position, parseError = ParseBracedVector(parser, "position")
    if position == nil then
        return nil, parseError
    end

    if Peek(parser) == nil then
        return {
            Position = position
        }, nil
    end

    local _
    _, parseError = ExpectToken(parser, "comma", `"," after the position`)
    if parseError ~= nil then
        return nil, parseError
    end

    local orientation
    orientation, parseError = ParseBracedVector(parser, "orientation")
    if orientation == nil then
        return nil, parseError
    end

    local trailingToken = Peek(parser)
    if trailingToken ~= nil then
        return nil,
            `Expected end of input after the orientation, found {DescribeToken(trailingToken)}.`
    end

    return {
        Position = position,
        Orientation = orientation
    }, nil
end

local function Tokenize(text: string): { Token }
    local tokens = {}

    for value, kind in CFrameLexer.lex(text) do
        table.insert(tokens, {
            Kind = kind,
            Value = value
        })
    end

    return tokens
end

local function ParseCFrame(text: string): (Components?, string?)
    local tokens = Tokenize(text)
    local parser: Parser = {
        Tokens = tokens,
        Position = 1
    }

    local firstToken = Peek(parser)
    if firstToken ~= nil and firstToken.Kind == "leftBrace" then
        return ParseBracedCFrame(parser)
    end

    return ParseFlatCFrame(parser)
end

return ParseCFrame
