--!strict

local StudioService = game:GetService("StudioService")

local Packages =
    script.Parent.Parent.Parent.Parent.Parent.Parent.Parent.Parent.packages

local Fusion = require(Packages.fusion)
local New, Children = Fusion.New, Fusion.Children

local Components = script.Parent.Parent.Parent.Parent.Parent
local Text = require(Components.text)
local Icon = require(Components.icon)

local Types = require(script.Parent.types)
local CreateSidePadding = require(script.Parent.utils.createSidePadding)

return function(
    scope: Fusion.Scope,
    props: Types.ValueVariantProps<Instance>
): Fusion.Child
    local value = props.Value

    local classIcon = StudioService:GetClassIcon(value.ClassName)

    return {
        Text(scope, {
            Text = value.Name,
            Variant = if props.Writable then "Primary" else "Secondary",
            Size = UDim2.fromScale(1, 0),
            LayoutOrder = 0,

            [Children] = New(scope, "UIFlexItem") {
                FlexMode = Enum.UIFlexMode.Shrink
            }
        }),

        Icon(scope, {
            Image = classIcon.Image,
            Size = UDim2.fromOffset(13, 13),
            ImageRectOffset = classIcon.ImageRectOffset,
            ImageRectSize = classIcon.ImageRectSize
        }),

        CreateSidePadding(scope)
    } :: Fusion.Child
end
