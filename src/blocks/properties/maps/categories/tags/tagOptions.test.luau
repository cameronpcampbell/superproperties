--!strict

local TagOptions = require("./tagOptions")

local allTags = {
    "Partial",
    "Shared",
    "Unused"
}
local tagsOnEveryInstance = {
    Shared = true
}

local options = TagOptions.Create(allTags, tagsOnEveryInstance, "")
assert(#options == 2, "expected only non-common tags")
assert(options[1].Tag == "Partial", "expected partial tag to remain")
assert(options[2].Tag == "Unused", "expected unused tag to remain")

local sharedSearchOptions =
    TagOptions.Create(allTags, tagsOnEveryInstance, "Shared")
for _, option in sharedSearchOptions do
    assert(option.Tag ~= "Shared", "expected common tag to stay hidden")
    assert(
        option.Label ~= "Create tag: Shared",
        "expected global tag not to be offered as new"
    )
end

local newTagOptions =
    TagOptions.Create(allTags, tagsOnEveryInstance, "  NewTag  ")
assert(#newTagOptions == 3, "expected create option and available tags")
assert(newTagOptions[1].Tag == "NewTag", "expected trimmed tag candidate")
assert(
    newTagOptions[1].Label == "Create tag: NewTag",
    "expected create option first"
)
assert(newTagOptions[2].Tag == "Partial", "expected sorted available tag")
assert(newTagOptions[3].Tag == "Unused", "expected sorted available tag")
