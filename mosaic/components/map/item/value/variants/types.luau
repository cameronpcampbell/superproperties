--!strict

local Packages =
    script.Parent.Parent.Parent.Parent.Parent.Parent.Parent.Parent.packages
local Fusion = require(Packages.fusion)

export type ValueVariantProps<T> = {
    Value: T
}

export type ValueVariantFn<T> =
    (pscope: Fusion.Scope, rops: ValueVariantProps<T>) -> Fusion.Child

return nil
