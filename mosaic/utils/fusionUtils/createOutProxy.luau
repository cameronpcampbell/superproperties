--!strict

local Packages = script.Parent.Parent.Parent.Parent

local Fusion = require(Packages.fusion)
local Peek, Value, Observer = Fusion.peek, Fusion.Value, Fusion.Observer

local function CreateOutProxy<T, S>(
    scope: Fusion.Scope,
    target: Fusion.Value<T, S>,
    source: Fusion.UsedAs<S>
): Fusion.Value<S>
    local proxy = Value(scope, Peek(source))
    local isUpdatingFromSource = false

    Observer(scope, source):onChange(function()
        isUpdatingFromSource = true
        proxy:set(Peek(source))
        isUpdatingFromSource = false
    end)

    Observer(scope, proxy):onChange(function()
        if isUpdatingFromSource then return end
        target:set(Peek(proxy))
    end)

    return proxy
end

return CreateOutProxy
