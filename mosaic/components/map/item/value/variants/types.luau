--!strict

local Packages =
    script.Parent.Parent.Parent.Parent.Parent.Parent.Parent.Parent.packages
local Fusion = require(Packages.fusion)

export type ValueVariantProps<T> = {
    Value: T,
    Writable: boolean,
    DisplayAsWritable: boolean,
    TrySetValue: ((value: T) -> (boolean, string?, T?))?,
    OnFocusChanged: ((isFocused: boolean) -> ())?,
    FocusState: Fusion.Value<boolean>?,
    HoverState: Fusion.Value<boolean>?
}

export type ValueVariantFn<T> =
    (pscope: Fusion.Scope, props: ValueVariantProps<T>) -> Fusion.Child

return nil
