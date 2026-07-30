--!strict

local ContentLexer = require(script.Parent.lexer)

type Token = {
	Kind: string?,
	Value: string,
}

type Parser = {
	Tokens: { Token },
	Position: number,
}

local SupportedSchemes: { [string]: boolean } = table.freeze({
	rbxassetid = true,
	rbxasset = true,
	rbxthumb = true,
	rbxgameasset = true,
	rbxhttp = true,
	rbxtemp = true,
	http = true,
	https = true,
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

local function ExpectToken(parser: Parser, expectedKind: string, expectation: string): (Token?, string?)
	local token = Peek(parser)
	if token == nil or token.Kind ~= expectedKind then
		return nil, `Expected {expectation}, found {DescribeToken(token)}.`
	end

	Advance(parser)
	return token, nil
end

local function ExpectEnd(parser: Parser): string?
	local trailingToken = Peek(parser)
	if trailingToken ~= nil then
		return `Expected end of input, found {DescribeToken(trailingToken)}.`
	end

	return nil
end

local function Tokenize(text: string): { Token }
	local tokens = {}

	for value, kind in ContentLexer.lex(text) do
		table.insert(tokens, {
			Kind = kind,
			Value = value,
		})
	end

	return tokens
end

local function Trim(text: string): string
	return string.match(text, "^%s*(.-)%s*$") or text
end

local function ParseAssetId(parser: Parser): (Content?, string?)
	local assetId, parseError = ExpectToken(parser, "assetId", "an asset ID")
	if assetId == nil then
		return nil, parseError
	end

	parseError = ExpectEnd(parser)
	if parseError ~= nil then
		return nil, parseError
	end

	return Content.fromUri(`rbxassetid://{assetId.Value}`), nil
end

local function ParseUriBody(parser: Parser): (Token?, string?)
	local token = Peek(parser)
	if token == nil or (token.Kind ~= "assetId" and token.Kind ~= "uriBody") then
		return nil, `Expected a non-empty URI body, found {DescribeToken(token)}.`
	end

	Advance(parser)
	return token, nil
end

local function ParseUri(parser: Parser): (Content?, string?)
	local schemeToken, parseError = ExpectToken(parser, "scheme", "an asset URI scheme")
	if schemeToken == nil then
		return nil, parseError
	end

	local scheme = string.lower(schemeToken.Value)
	if not SupportedSchemes[scheme] then
		return nil, `Unsupported asset URI scheme {string.format("%q", schemeToken.Value)}.`
	end

	local separator
	separator, parseError = ExpectToken(parser, "separator", `"://" after the URI scheme`)
	if separator == nil then
		return nil, parseError
	end

	local body
	body, parseError = ParseUriBody(parser)
	if body == nil then
		return nil, parseError
	end

	if scheme == "rbxassetid" and body.Kind ~= "assetId" then
		return nil, `Expected decimal digits after "rbxassetid://", found {DescribeToken(body)}.`
	end

	parseError = ExpectEnd(parser)
	if parseError ~= nil then
		return nil, parseError
	end

	return Content.fromUri(`{scheme}://{body.Value}`), nil
end

local function ParseContent(text: string): (Content?, string?)
	local parser: Parser = {
		Tokens = Tokenize(Trim(text)),
		Position = 1,
	}

	local firstToken = Peek(parser)
	if firstToken ~= nil and firstToken.Kind == "assetId" then
		return ParseAssetId(parser)
	end

	return ParseUri(parser)
end

return ParseContent
