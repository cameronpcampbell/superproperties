--!strict

local CreateTextVariant = require(script.Parent.utils.createTextVariant)
local ParseContent = require(script.parser)

local function FormatContent(value: Content): string
	if value.SourceType == Enum.ContentSourceType.Uri then
		return value.Uri :: string
	elseif value.SourceType == Enum.ContentSourceType.None then
		return ""
	end

	return `<{value.SourceType.Name} content>`
end

return CreateTextVariant
	<< Content
	>> {
		InputName = "ContentValueInput",
		Format = FormatContent,
		Parse = ParseContent,
	}
