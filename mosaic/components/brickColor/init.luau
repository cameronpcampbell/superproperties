--!strict
--!nolint LocalShadow

local Packages = script.Parent.Parent.Parent

local Fusion = require(Packages.fusion)
local New, Children = Fusion.New, Fusion.Children

local Utils = script.Parent.Parent.utils

local FusionUtils = require(Utils.fusionUtils)
local Component, CombineProps =
    FusionUtils.Component, FusionUtils.CombineProps

local ThemeUtils = require(Utils.themeUtils)
local GetThemeForScope = ThemeUtils.GetThemeForScope

local TableUtils = require(Utils.tableUtils)
local TableExtract = TableUtils.Extract

local Assets = require(script.Parent.Parent.assets)

type BrickColorProps = {

}

local function BrickColorItem(scope: Fusion.Scope)
    return New(scope, "ImageButton") {
        Size = UDim2.fromOffset(20, 23),
        Image = Assets.BrickColor,

        [Children] = {
            New(scope, "ImageLabel") {
                Size = UDim2.fromScale(1, 1),
                Image = Assets.BrickColorStroke,
            }
        }
    }
end

return Component<<BrickColorProps>>(function(scope, props)


    local theme = GetThemeForScope(scope)


    return New(scope, "Frame") (CombineProps({

    }, props))
end)
