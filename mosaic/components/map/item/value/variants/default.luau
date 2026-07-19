
--!strict

local Packages =
    script.Parent.Parent.Parent.Parent.Parent.Parent.Parent.Parent.packages
local Fusion = require(Packages.fusion)
local New, Children = Fusion.New, Fusion.Children

local Types = require(script.Parent.types)
local CreateSidePadding = require(script.Parent.utils.createSidePadding)

local Components = script.Parent.Parent.Parent.Parent.Parent
local Text = require(Components.text)

return function(
    scope: Fusion.Scope,
    props: Types.ValueVariantProps<any>
): Fusion.Child
    local value = props.Value

    return {
        Text(scope, {
            Text = tostring(value),
            Variant = if props.Writable then "Primary" else "Secondary",
            Size = UDim2.fromScale(1, 0),

            [Children] = New(scope, "UIFlexItem") {
                FlexMode = Enum.UIFlexMode.Shrink
            }
        }),

        CreateSidePadding(scope)
    } :: Fusion.Child
end
