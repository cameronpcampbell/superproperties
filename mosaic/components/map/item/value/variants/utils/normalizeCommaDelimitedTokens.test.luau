--!strict

local NormalizeCommaDelimitedTokens =
    require("./normalizeCommaDelimitedTokens")
type Token = NormalizeCommaDelimitedTokens.Token

local function Token(kind: string?, value: string): Token
    return {
        Kind = kind,
        Value = value
    }
end

local normalized = NormalizeCommaDelimitedTokens({
    Token("number", "1"),
    Token("comma", ","),
    Token("comma", ","),
    Token("comma", ","),
    Token("number", "2"),
    Token("comma", ","),
    Token("comma", ","),
    Token("rightBrace", "}"),
    Token("comma", ","),
    Token("comma", ",")
})

assert(#normalized == 4, `expected 4 normalized tokens, got {#normalized}`)
assert(
    normalized[1].Kind == "number"
    and normalized[2].Kind == "comma"
    and normalized[3].Kind == "number"
    and normalized[4].Kind == "rightBrace",
    "expected comma chains and trailing commas to normalize"
)

local leadingComma = NormalizeCommaDelimitedTokens({
    Token("comma", ","),
    Token("comma", ","),
    Token("number", "1")
})

assert(
    #leadingComma == 2 and leadingComma[1].Kind == "comma",
    "leading commas should remain available for parser validation"
)

print("comma-delimited token normalization verification passed")
