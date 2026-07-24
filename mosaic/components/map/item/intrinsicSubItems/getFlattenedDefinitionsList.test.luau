--!strict

local GetFlattenedDefinitionsList =
    require("./getFlattenedDefinitionsList")

local function AssertKeys(items: { any }, expectedKeys: { string })
    assert(
        #items == #expectedKeys,
        `expected {#expectedKeys} items, got {#items}`
    )

    for idx, expectedKey in expectedKeys do
        assert(
            items[idx].Key == expectedKey,
            `expected key '{expectedKey}' at index {idx}, got '{items[idx].Key}'`
        )
    end
end

AssertKeys(GetFlattenedDefinitionsList("UDim2"), {
    "X", "Scale", "Offset", "Y", "Scale", "Offset"
})
AssertKeys(GetFlattenedDefinitionsList("CFrame"), {
    "Position", "X", "Y", "Z", "Orientation", "X", "Y", "Z"
})
assert(#GetFlattenedDefinitionsList("UnsupportedType") == 0)

print("intrinsicSubItems verification passed")
