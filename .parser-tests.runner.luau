local ServerScriptService = game:GetService("ServerScriptService")
local variants = ServerScriptService.superproperties.packages.mosaic.components.map.item.value.variants

local tests = {
	variants.utils["normalizeCommaDelimitedTokens.test"],
	variants.mathExpression["parser.test"],
	variants.vector["parser.test"],
	variants.vector2["parser.test"],
	variants.udim["parser.test"],
	variants.udim2["parser.test"],
	variants.cframe["parser.test"],
	variants.color["parser.test"],
	variants.content["parser.test"],
}

for _, testModule in tests do
	require(testModule)
end

print("all parser verification passed")
