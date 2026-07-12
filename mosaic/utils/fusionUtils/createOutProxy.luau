--!strict

local Packages = script.Parent.Parent.Parent.Parent

local Fusion = require(Packages.fusion)
local Peek, Value, Observer = Fusion.peek, Fusion.Value, Fusion.Observer

local function CreateOutProxy<T, S>(
    scope: Fusion.Scope,
    target: Fusion.Value<T, S>,
    initialValue: S
): Fusion.Value<S>
    local proxy = Value(scope, initialValue)

    Observer(scope, proxy):onChange(function()
        target:set(Peek(proxy))
    end)

    return proxy
end

return CreateOutProxy
