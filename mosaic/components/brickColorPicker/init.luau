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

local CoreComponents = script.Parent.Parent.coreComponents
local AdaptiveHighlight = require(CoreComponents.adaptiveHighlight)

local Assets = require(script.Parent.Parent.assets)

type BrickColorItemProps = {
    Color: Color3
}

local function NewUnscoped(name: string)
    return function(
        scope: Fusion.Scope,
        props: { [any]: any }
    ): Fusion.Child
        return New(scope, name)(props)
    end
end

local function BrickColorItem(
    scope: Fusion.Scope,
    props: BrickColorItemProps
)
    return New(scope, "ImageButton") {
        Size = UDim2.fromOffset(20, 23),
        Image = Assets.BrickColor,
        ImageColor3 = props.Color,
        BackgroundTransparency = 1,

        [Children] = {
            AdaptiveHighlight(scope, NewUnscoped("ImageLabel"), {
                Size = UDim2.fromScale(1, 1),
                Image = Assets.BrickColorStroke,
                BackgroundTransparency = 1,
            }),

            New(scope, "UIFlexItem") {}
        }
    }
end

type BrickColorProps = {

}

return Component<<BrickColorProps>>(function(scope, props)
    return New(scope, "Frame") (CombineProps({
        [Children] = BrickColorItem(scope, {
            Color = BrickColor.Random().Color
        })
    }, props))
end)
