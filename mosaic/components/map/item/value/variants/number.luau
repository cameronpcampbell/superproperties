
--!strict

local Packages =
    script.Parent.Parent.Parent.Parent.Parent.Parent.Parent.Parent.packages
local Fusion = require(Packages.fusion)

local Types = require(script.Parent.types)

local Components = script.Parent.Parent.Parent.Parent.Parent
local Text = require(Components.text)

return function(scope: Fusion.Scope, props: Types.ValueVariantProps<number>)
    local value = props.Value

    return Text(scope, {
        Text = tostring(math.round(value)),
        Variant = if props.Writable then "Primary" else "Secondary",
        Size = UDim2.fromScale(1, 0),
    })
end
