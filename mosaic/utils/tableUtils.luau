--!strict

local Packages = script.Parent.Parent.Parent
local Typeforge = require(Packages.typeforge)

type function safe_is(input: type, isType: string)
    if typeof(input) ~= "userdata" then return false end

    local is = (input :: type).is
    if not is then return false end
    return is(input :: type, isType)
end

type function safe_value(input: type): any
    if safe_is(input, "singleton") then return input:value() end
    return input
end

-- For our use case we are purposefully omitting `types.singleton(false)` from this list.
type function is_falsey(input: type)
    return
        input == types.singleton(nil) or
        input == types.never or
        input == types.unknown
end

type Pick<I, P> = Typeforge.Pick<I, P>
type Omit<I, O> = Typeforge.Omit<I, O>

type function OmitExceptIndexer(input: type, toOmit: type)
    assert(input.tag, "table")

    local indexer = input:indexer()

    local omittedInput: type = types.copy(Omit(input, toOmit))

    if indexer then
        omittedInput
            :setindexer(indexer.index, indexer.readresult)
    end

    return omittedInput
end

type Falsey = nil | never | unknown

-- We need to make the return type optional only when a default value is not provided.
type function ExtractReturnType(propValue: type, default: type)
    -- Issue with Pick with non-string singletons in typeforge.
    if not safe_is(default, "union") then
        return
            if is_falsey(default) then propValue
            else Omit(propValue, types.singleton(nil))
    end

    return
        if Pick(default, Falsey) ~= types.unknown then propValue
        else Omit(propValue, types.singleton(nil))
end

local function Extract<T, P, D>(
    tble: T, prop: P | "",
    default: ((D & index<T, P>) | "")?
): (OmitExceptIndexer<T, P>, ExtractReturnType<index<T, P>, D>)
    local value = (tble :: { [any]: any })[prop]

    if value ~= nil then
        (tble :: { [any]: any })[prop] = nil

        return tble, value

    else
        return tble, default :: any
    end
end

return {
    Extract = Extract
}
