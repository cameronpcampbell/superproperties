--!strict

return function(value: boolean?, defaultValue: boolean): boolean
    return if value == nil then defaultValue else value
end
