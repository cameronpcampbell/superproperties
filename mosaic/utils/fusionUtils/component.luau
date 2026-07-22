--!strict

local Packages = script.Parent.Parent.Parent.Parent
local Fusion = require(Packages.fusion)
local Typeforge = require(Packages.typeforge)

local CombineProps = require(script.Parent.combineProps)

type Props<P> = Typeforge.FlattenTable<
    & P
    & {
        [string | Fusion.SpecialKey]: any
    }
>

type Callback<P> = (
    scope: Fusion.Scope,
    props: Props<P>
) -> Fusion.Child

type Constructor = (
    scope: Fusion.Scope,
    props: { [any]: any }
) -> Fusion.Child

type ConstructorCallback<P> = (
    scope: Fusion.Scope,
    constructor: Constructor,
    props: Props<P>
) -> Fusion.Child

local function Component<P>(callback: Callback<P>)
    return function(
        scope: Fusion.Scope,
        props: P,
        ...: Props<Typeforge.Partial<P>>
    ): Fusion.Child
        return (callback :: any)(
            scope,
            CombineProps(props :: any, ...)
        )
    end
end

local function ConstructorComponent<P>(callback: ConstructorCallback<P>)
    return function(
        scope: Fusion.Scope,
        constructor: Constructor,
        props: P,
        ...: Props<Typeforge.Partial<P>>
    ): Fusion.Child
        return (callback :: any)(
            scope,
            constructor,
            CombineProps(props :: any, ...)
        )
    end
end

return {
    Component = Component,
    ConstructorComponent = ConstructorComponent,
}
