--!strict

local ParseUDim = require(script.Parent.Parent.udim.parser)
local UDim2Lexer = require(script.Parent.lexer)

type UDimComponents = {
    Scale: number,
    Offset: number
}

export type Components = {
    X: UDimComponents,
    Y: UDimComponents
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

local function ParseAxisUDim(
    text: string,
    axisName: string
): (UDimComponents?, string?)
    local components, parseError = ParseUDim(text)
    if components == nil then
        return nil, `Invalid {axisName} UDim: {parseError or "Invalid value."}`
    end

    return components, nil
end

local function ParseBracedUDim(
    parser: Parser,
    axisName: string
): (UDimComponents?, string?)
    local _, parseError =
        ExpectToken(parser, "leftBrace", `a left brace before the {axisName} UDim`)
    if parseError ~= nil then
        return nil, parseError
    end

    local parts: { string } = {}

    while true do
        local token = Peek(parser)
        if token == nil then
            return nil,
                `Expected a right brace after the {axisName} UDim, found end of input.`
        end

        if token.Kind == "rightBrace" then
            Advance(parser)
            break
        end

        table.insert(parts, token.Value)
        Advance(parser)
    end

    return ParseAxisUDim(table.concat(parts, " "), axisName)
end

local function ParseBracedUDim2(parser: Parser): (Components?, string?)
    local x, parseError = ParseBracedUDim(parser, "x")
    if x == nil then
        return nil, parseError
    end

    local _
    _, parseError = ExpectToken(parser, "comma", `"," after the x UDim`)
    if parseError ~= nil then
        return nil, parseError
    end

    local y
    y, parseError = ParseBracedUDim(parser, "y")
    if y == nil then
        return nil, parseError
    end

    local trailingToken = Peek(parser)
    if trailingToken ~= nil then
        return nil,
            `Expected end of input after the y UDim, found {DescribeToken(trailingToken)}.`
    end

    return {
        X = x,
        Y = y
    }, nil
end

local function SplitComponents(tokens: { Token }): { string }
    local componentParts: { { string } } = { {} }

    for _, token in tokens do
        if token.Kind == "comma" then
            table.insert(componentParts, {})
            continue
        end

        local currentParts = componentParts[#componentParts]
        table.insert(currentParts, token.Value)
    end

    local components = {}
    for _, parts in componentParts do
        table.insert(components, table.concat(parts, " "))
    end

    return components
end

local function ParseFlatUDim2(tokens: { Token }): (Components?, string?)
    local components = SplitComponents(tokens)
    local componentCount = #components

    if componentCount ~= 1 and componentCount ~= 2 and componentCount ~= 4 then
        return nil, "Enter either 1, 2, or 4 numerical components."
    end

    local xText: string
    local yText: string

    if componentCount == 1 then
        xText = components[1]
        yText = components[1]
    elseif componentCount == 2 then
        xText = components[1]
        yText = components[2]
    else
        xText = string.format("%s, %s", components[1], components[2])
        yText = string.format("%s, %s", components[3], components[4])
    end

    local x, parseError = ParseAxisUDim(xText, "x")
    if x == nil then
        return nil, parseError
    end

    local y
    y, parseError = ParseAxisUDim(yText, "y")
    if y == nil then
        return nil, parseError
    end

    return {
        X = x,
        Y = y
    }, nil
end

local function Tokenize(text: string): { Token }
    local tokens = {}

    for value, kind in UDim2Lexer.lex(text) do
        table.insert(tokens, {
            Kind = kind,
            Value = value
        })
    end

    return tokens
end

local function ParseUDim2(text: string): (Components?, string?)
    local tokens = Tokenize(text)
    local firstToken = tokens[1]

    if firstToken ~= nil and firstToken.Kind == "leftBrace" then
        return ParseBracedUDim2({
            Tokens = tokens,
            Position = 1
        })
    end

    return ParseFlatUDim2(tokens)
end

return ParseUDim2
