--!strict

export type TagSet = { [string]: boolean }

export type Option = {
    Tag: string,
    Label: string
}

local function Trim(text: string): string
    return text:match("^%s*(.-)%s*$") or ""
end

local function Create(
    allTags: { string },
    tagsOnEveryInstance: TagSet,
    query: string
): { Option }
    local candidate = Trim(query)
    local exactGlobalMatch = table.find(allTags, candidate) ~= nil
    local hasCreateOption = candidate ~= "" and not exactGlobalMatch
    local options = table.create(
        #allTags + (if hasCreateOption then 1 else 0)
    ) :: { Option }
    local optionIdx = 1

    if hasCreateOption then
        options[optionIdx] = {
            Tag = candidate,
            Label = `Create tag: {candidate}`
        }
        optionIdx += 1
    end

    for _, tag in allTags do
        if tagsOnEveryInstance[tag] then continue end

        options[optionIdx] = {
            Tag = tag,
            Label = tag
        }
        optionIdx += 1
    end

    return options
end

return {
    Create = Create,
    Trim = Trim
}
