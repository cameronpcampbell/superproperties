--!strict

local Packages =
    script.Parent.Parent.Parent.Parent.Parent.Parent.Parent.Parent.Parent.packages
local Lexuau = require(Packages.lexuau)

export type Components = {
    X: number,
    Y: number,
    Z: number
}

type Token = {
    Kind: string?,
    Value: string
}

type Parser = {
    Tokens: { Token },
    Position: number
}

local VectorLexer = Lexuau.new<<nil>>({
    skip = "[ \t\n\r\f]+",
    init_state = function()
        return nil
    end,

    subpatterns = {
        numsect = "_*[\\d]+_*",
        num = "((?&numsect)+\\.)?(?&numsect)+|\\.(?&numsect)"
    },

    patterns = {
        number = "(?&num)",
        comma = ",",
        sign = "[+-]"
    }
})

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

    for value, kind in VectorLexer.lex(text) do
        table.insert(tokens, {
            Kind = kind,
            Value = value
        })
    end

    return tokens
end

local function ParseVector(text: string): (Components?, string?)
    local parser: Parser = {
        Tokens = Tokenize(text),
        Position = 1
    }

    local x, parseError = ParseComponent(parser, "x")
    if x == nil then
        return nil, parseError
    end

    local success
    success, parseError = ParseComma(parser, "x")
    if not success then
        return nil, parseError
    end

    local y
    y, parseError = ParseComponent(parser, "y")
    if y == nil then
        return nil, parseError
    end

    success, parseError = ParseComma(parser, "y")
    if not success then
        return nil, parseError
    end

    local z
    z, parseError = ParseComponent(parser, "z")
    if z == nil then
        return nil, parseError
    end

    local trailingToken = Peek(parser)
    if trailingToken ~= nil then
        return nil,
            `Expected end of input after the z component, found {DescribeToken(trailingToken)}.`
    end

    return {
        X = x,
        Y = y,
        Z = z
    }, nil
end

return ParseVector
