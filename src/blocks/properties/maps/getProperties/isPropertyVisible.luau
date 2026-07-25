--!strict

export type Rule<T> =
    boolean | ((instance: T, value: any) -> boolean)

return function<T>(
    rule: Rule<T>?,
    instance: T,
    value: any
): boolean
    if rule == nil then return true end
    if type(rule) == "boolean" then return rule end

    return rule(instance, value)
end
