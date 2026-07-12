--!strict

local Packages = script.Parent.Parent.Parent.Parent

local Fusion = require(Packages.fusion)
local Peek, Value, Observer = Fusion.peek, Fusion.Value, Fusion.Observer

local function CreateOutProxy<T>(
    scope: Fusion.Scope,
    source: Fusion.UsedAs<T>,
    write: (T) -> ()
): Fusion.Value<T>
    local proxy = Value(scope, Peek(source))
    local isUpdatingFromSource = false

    Observer(scope, source):onChange(function()
        isUpdatingFromSource = true
        proxy:set(Peek(source))
        isUpdatingFromSource = false
    end)

    Observer(scope, proxy):onChange(function()
        if isUpdatingFromSource then return end
        write(Peek(proxy))
    end)

    return proxy :: any
end

return CreateOutProxy
