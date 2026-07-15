--!strict

local Packages =
    script.Parent.Parent.Parent.Parent.Parent.Parent.Parent.Parent.packages
local Fusion = require(Packages.fusion)

local Types = require(script.Parent.types)

local Components = script.Parent.Parent.Parent.Parent.Parent
local Checkbox = require(Components.checkbox)

return function(scope: Fusion.Scope, props: Types.ValueVariantProps<boolean>)
    return Checkbox(scope, {
        Checked = props.Value
    })
end
