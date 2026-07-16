--!strict

local Packages =
    script.Parent.Parent.Parent.Parent.Parent.Parent.Parent.Parent.packages
local Fusion = require(Packages.fusion)

local Types = require(script.Parent.types)

local Components = script.Parent.Parent.Parent.Parent.Parent
local Checkbox = require(Components.checkbox)

return function(scope: Fusion.Scope, props: Types.ValueVariantProps<boolean>)
    local trySetValue = props.TrySetValue

    return Checkbox(scope, {
        Checked = props.Value,
        Disabled = not props.Writable or trySetValue == nil,
        OnChanged =
            if trySetValue then
                function(value: boolean)
                    local success, err = trySetValue(value)
                    if success then return end

                    warn(`SuperProperties: {err or "Could not set value."}`)
                end
            else nil
    })
end
