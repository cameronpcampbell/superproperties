--!strict
--!nolint LocalShadow

local Packages = script.Parent.Parent.Parent

local Typeforge = require(Packages.typeforge)
type Flatten<I> = Typeforge.Flatten<I>
type PickUnion<I, P> = Typeforge.PickUnion<I, P>
type OmitUnion<I, O> = Typeforge.OmitUnion<I, O>

local Fusion = require(Packages.fusion)
type FusionUsedAs<T> = Fusion.UsedAs<T>

type function safe_is(input: type, isType: string)
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

type function OmitExceptIndexer(input: type, toOmit: type)
    assert(input.tag, "table")

    local indexer = input:indexer()

    local omittedInput: type = types.copy(OmitUnion(input, toOmit))

    if indexer then
        omittedInput
            :setindexer(indexer.index, indexer.readresult)
    end

    return omittedInput
end

type function union_from_components(input: { type })
    local input_len = #input
    return if input_len == 0 then nil elseif input_len == 1 then input[1] else types.unionof(table.unpack(input))
end

type function intersection_from_components(input: { type })
    local input_len = #input
    return if input_len == 0 then nil elseif input_len == 1 then input[1] else types.intersectionof(table.unpack(input))
end

type function components_map(
    input: { type },
    callback: (value: type, ...type) -> type,
    ...: type
)
    for idx, value in input do
        input[idx] = callback(value, ...)
    end
    return input
end

type function ExtractUsedAsValue(input: type)
    local input = Flatten(input)
    local inputTag = input.tag

    if inputTag == "union" then
        for _, component in input:components() do
            local extracted = ExtractUsedAsValue(component)
            if extracted then return extracted end
        end

        return nil
    end

    if input.tag ~= "table" then return nil end

    return input:readproperty(
        types.singleton("_EXTREMELY_DANGEROUS_usedAsValue")
    )
end

type function PropValueConversion(propValue: type, convert: boolean)
    return if convert then FusionUsedAs(propValue) else propValue
end

type Falsey = nil | never | unknown

-- We need to make the return type optional only when a default value is not provided.
type function ExtractReturnType(propValue: type, default: type)
    local convertPropValue = false

    local propValueUsedAs = ExtractUsedAsValue(propValue)
    if propValueUsedAs then
        propValue = propValueUsedAs
        convertPropValue = true
    end

    local defaultUsedAs = ExtractUsedAsValue(default)
    if defaultUsedAs then
        default = defaultUsedAs
    end

    -- Issue with Pick with non-string singletons in typeforge.
    if not safe_is(default, "union") then
        return
            if is_falsey(default) then
                PropValueConversion(propValue, convertPropValue)
            else PropValueConversion(OmitUnion(propValue, types.singleton(nil)), convertPropValue)
    end

    return
        if PickUnion(default, Falsey) ~= types.unknown then
            PropValueConversion(propValue, convertPropValue)
        else PropValueConversion(OmitUnion(propValue, types.singleton(nil)), convertPropValue)
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
