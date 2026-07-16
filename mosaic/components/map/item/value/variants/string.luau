
--!strict

local CreateTextVariant = require(script.Parent.utils.createTextVariant)

return CreateTextVariant<<string>>({
    InputName = "StringValueInput",

    Format = function(value: string): string
        return value
    end,

    Parse = function(text: string): (string?, string?)
        return text, nil
    end
})
