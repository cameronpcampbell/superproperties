--!strict

local Packages =
    script.Parent.Parent.Parent.Parent.Parent.Parent.Parent.Parent.Parent.packages
local Lexuau = require(Packages.lexuau)

type Token = {
    Kind: string?,
    Value: string
}

type Parser = {
    Tokens: { Token },
    Position: number
}

type Component = {
    Value: number,
    ExplicitDecimal: boolean
}

local HexLexer = Lexuau.new<<nil>>({
    skip = "[ \t\n\r\f]+",
    init_state = function()
        return nil
    end,

    patterns = {
        hex = "[\\da-fA-F]+"
    }
})

local ColorLexer = Lexuau.new<<nil>>({
    skip = "[ \t\n\r\f]+",
    init_state = function()
        return nil
    end,

    subpatterns = {
        numsect = "_*[\\d]+_*",
        num = "((?&numsect)+\\.)?(?&numsect)+|\\.(?&numsect)"
    },

    patterns = {
        hash = {
            pattern = "#",
            callback = function(value: string, _state: nil)
                return value, HexLexer
            end
        },
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
): (Component?, string?)
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

    return {
        Value = sign * value,
        ExplicitDecimal = string.find(token.Value, ".", 1, true) ~= nil
    }, nil
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
    component: Component,
    componentName: string
): (number?, string?)
    local normalizedValue =
        if component.ExplicitDecimal then component.Value * 255 else component.Value

    if normalizedValue < 0 or normalizedValue > 255 then
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

    local red, green, blue

    red, parseError = NormalizeComponent(redComponent, "red")
    if red == nil then return nil, parseError end

    green, parseError = NormalizeComponent(greenComponent, "green")
    if green == nil then return nil, parseError end

    blue, parseError = NormalizeComponent(blueComponent, "blue")
    if blue == nil then return nil, parseError end

    return Color3.fromRGB(red, green, blue), nil
end

local function ParseColor(text: string): (Color3?, string?)
    local parser: Parser = {
        Tokens = Tokenize(text),
        Position = 1
    }

    local firstToken = Peek(parser)
    if firstToken ~= nil and firstToken.Kind == "hash" then
        return ParseHex(parser)
    end

    return ParseRgb(parser)
end

return ParseColor
