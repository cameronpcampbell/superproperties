--!strict

local Packages =
    script.Parent.Parent.Parent.Parent.Parent.Parent.Parent.Parent.packages
local Fusion = require(Packages.fusion)

export type ValueVariantProps<T> = {
    Value: T,
    Writable: boolean,
    TrySetValue: ((value: T) -> (boolean, string?))?
}

export type ValueVariantFn<T> =
    (pscope: Fusion.Scope, props: ValueVariantProps<T>) -> Fusion.Child

return nil
