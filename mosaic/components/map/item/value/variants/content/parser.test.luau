--!strict

local ParseContent = require("./parser")

local function AssertUri(text: string, expectedUri: string, label: string)
	local actual, parseError = ParseContent(text)
	assert(actual ~= nil, `{label}: expected Content, got {parseError or "an invalid value"}`)
	assert(typeof(actual) == "Content", `{label}: expected typeof Content, got {typeof(actual)}`)
	assert(actual.SourceType == Enum.ContentSourceType.Uri, `{label}: expected URI-backed Content`)
	assert(actual.Uri == expectedUri, `{label}: expected {expectedUri}, got {actual.Uri or "no URI"}`)
end

local function AssertInvalid(text: string, label: string)
	local actual, parseError = ParseContent(text)
	assert(actual == nil and parseError ~= nil, `{label}: expected an invalid Content value`)
end

AssertUri("123456", "rbxassetid://123456", "asset ID shorthand")
AssertUri("  123456  ", "rbxassetid://123456", "trimmed shorthand")
AssertUri("rbxassetid://7229442422", "rbxassetid://7229442422", "asset ID URI")
AssertUri("rbxasset://textures/face.png", "rbxasset://textures/face.png", "Roblox content URI")
AssertUri(
	"rbxthumb://type=Asset&id=24813339&w=150&h=150",
	"rbxthumb://type=Asset&id=24813339&w=150&h=150",
	"thumbnail URI"
)
AssertUri("rbxgameasset://Images/Potion", "rbxgameasset://Images/Potion", "game asset URI")
AssertUri(
	"rbxhttp://Thumbs/Avatar.ashx?x=100&y=100&format=png",
	"rbxhttp://Thumbs/Avatar.ashx?x=100&y=100&format=png",
	"Roblox HTTP URI"
)
AssertUri("rbxtemp://1", "rbxtemp://1", "temporary content URI")
AssertUri("https://www.roblox.com/asset/?id=9723979220", "https://www.roblox.com/asset/?id=9723979220", "HTTPS URI")
AssertUri("http://www.roblox.com/asset/?id=9723979220", "http://www.roblox.com/asset/?id=9723979220", "HTTP URI")
AssertUri(
	"HTTPS://www.roblox.com/asset/?id=9723979220",
	"https://www.roblox.com/asset/?id=9723979220",
	"case-insensitive URI scheme"
)

AssertInvalid("", "empty input")
AssertInvalid("   ", "whitespace-only input")
AssertInvalid("hello", "plain text")
AssertInvalid("-123", "negative number")
AssertInvalid("+123", "signed number")
AssertInvalid("1.5", "decimal number")
AssertInvalid("1e3", "scientific notation")
AssertInvalid("1_000", "underscored number")
AssertInvalid("123abc", "number with trailing text")
AssertInvalid("ftp://example.com/file", "unsupported scheme")
AssertInvalid("rbxassetid:123", "missing scheme separator")
AssertInvalid("rbxassetid://", "missing asset ID URI body")
AssertInvalid("rbxassetid://abc", "non-numeric asset ID URI")
AssertInvalid("rbxassetid://123/456", "asset ID URI path")
AssertInvalid("https://", "missing HTTPS URI body")
AssertInvalid("https:// www.roblox.com", "space after URI separator")
AssertInvalid("https://www.roblox.com /asset", "space inside URI")
AssertInvalid("123 456", "multiple shorthand values")

print("Content parser verification passed")
