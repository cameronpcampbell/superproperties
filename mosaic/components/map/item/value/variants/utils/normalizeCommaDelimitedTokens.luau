--!strict

export type Token = {
    Kind: string?,
    Value: string
}

local function NormalizeCommaDelimitedTokens(
    tokens: { Token }
): { Token }
    local normalizedTokens: { Token } = {}
    local pendingComma: Token? = nil

    for _, token in tokens do
        if token.Kind == "comma" then
            pendingComma = pendingComma or token
            continue
        end

        if pendingComma ~= nil and token.Kind ~= "rightBrace" then
            table.insert(normalizedTokens, pendingComma)
        end

        pendingComma = nil
        table.insert(normalizedTokens, token)
    end

    return normalizedTokens
end

return NormalizeCommaDelimitedTokens
