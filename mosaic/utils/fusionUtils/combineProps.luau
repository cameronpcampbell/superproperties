--!strict

local Packages = script.Parent.Parent.Parent.Parent
local Fusion = require(Packages.fusion)


local Children = Fusion.Children

local function CombineProps(...: { [any]: any }): { [any]: any }
    local combinedProps = {}
	local combinedChildren = {}

	for idx, props in { ... } do
		for propName, propValue in props do
			if propName == Children then
			    table.insert(combinedChildren, propValue)

			else
			    combinedProps[propName] = propValue
			end
		end
	end

	if #combinedChildren ~= 0 then
		combinedProps[Children] = combinedChildren
	end

	return combinedProps
end

return CombineProps
