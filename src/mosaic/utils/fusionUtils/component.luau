--!strict

local Packages = script.Parent.Parent.Parent.Parent.packages
local Fusion = require(Packages.fusion)
local Typeforge = require(Packages.typeforge)

local CombineProps = require(script.Parent.combineProps)

type Props<P> = Typeforge.FlattenTable<P & Fusion.PropertyTable>

type Callback<P> = (
    scope: Fusion.Scope,
    props: Props<P>
) -> Fusion.Child

return function<P>(callback: Callback<P>)
    return function(
        scope: Fusion.Scope,
        props: P,
        ...: Props<Typeforge.Partial<P>>
    ): Fusion.Child
        return (callback :: any)(scope, CombineProps(props, ...))
    end
end
