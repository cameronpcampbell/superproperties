--!strict

local Packages = script.Parent.Parent.Parent.packages

local Fusion = require(Packages.fusion)

local Mosaic = require(Packages.mosaic)
local Input, IconButton = Mosaic.Input, Mosaic.IconButton

local Assets = require(script.Parent.Parent.Parent.assets)
local GetFilterState = require(script.Parent.getFilterState)

return function(scope: Fusion.Scope)
    local filterState = GetFilterState(scope)

    return Input(scope, {
        PlaceholderText = "Filter Properties",
        Text = filterState,

        LeftChildren = IconButton(scope, {
            Image = Assets.Search,
        })
    })
end
