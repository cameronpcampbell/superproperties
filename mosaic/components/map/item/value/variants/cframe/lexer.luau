--!strict

local Packages =
    script.Parent.Parent.Parent.Parent.Parent.Parent.Parent.Parent.Parent.packages
local Lexuau = require(Packages.lexuau)

local CreateDelimitedNumbersLexer =
    require(script.Parent.Parent.utils.createDelimitedNumbersLexer)

local cframePatterns: { [string]: Lexuau.PatternConfig<nil> } = {
    leftBrace = "{",
    rightBrace = "}"
}

return CreateDelimitedNumbersLexer(cframePatterns)
