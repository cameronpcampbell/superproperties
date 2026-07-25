--!strict

local GroupPropertyTargets =
    require("./groupPropertyTargets")

local workspaceTarget: { Value: string? } = {}
local textBoxTextTarget: { Value: string? } = {}
local textBoxNameTarget: { Value: string? } = { Value = "TextBox" }
local workspaceNameTarget: { Value: string? } = { Value = "Workspace" }
local unrelatedNameTarget: { Value: string? } = {}

local groups, categoryNames = GroupPropertyTargets({
    {
        Id = "Workspace\0Gravity",
        Name = "Gravity",
        CategoryName = "Behavior",
        ValueType = "number",
        Target = workspaceTarget,
        Writable = true
    },
    {
        Id = "TextBox\0Text",
        Name = "Text",
        CategoryName = "Text",
        ValueType = "string",
        Target = textBoxTextTarget,
        Writable = true
    },
    {
        Id = "Instance\0Name",
        Name = "Name",
        CategoryName = "Data",
        ValueType = "string",
        Target = workspaceNameTarget,
        Writable = true
    },
    {
        Id = "Instance\0Name",
        Name = "Name",
        CategoryName = "Data",
        ValueType = "string",
        Target = textBoxNameTarget,
        Writable = false
    },
    {
        Id = "Unrelated\0Name",
        Name = "Name",
        CategoryName = "Other",
        ValueType = "string",
        Target = unrelatedNameTarget,
        Writable = true
    }
})

assert(#groups == 4)
assert(#categoryNames == 4)
assert(categoryNames[1] == "Behavior")
assert(categoryNames[2] == "Text")
assert(categoryNames[3] == "Data")
assert(categoryNames[4] == "Other")

local gravityGroup = groups[1]
assert(#gravityGroup.Targets == 1)
assert(gravityGroup.Targets[1] == workspaceTarget)

-- A property contributed by only one selected class remains in the union.
local textGroup = groups[2]
assert(#textGroup.Targets == 1)
assert(textGroup.Targets[1] == textBoxTextTarget)

-- A shared reflected descriptor has both instances as write targets.
local sharedNameGroup = groups[3]
assert(#sharedNameGroup.Targets == 2)
assert(sharedNameGroup.Targets[1] == workspaceNameTarget)
assert(sharedNameGroup.Targets[2] == textBoxNameTarget)
assert(sharedNameGroup.Targets[1].Value ~= sharedNameGroup.Targets[2].Value)
assert(not sharedNameGroup.AllWritable)

-- Same-name properties with different reflected owners stay distinct until
-- Studio parity testing demonstrates that their editor contracts match.
local unrelatedNameGroup = groups[4]
assert(#unrelatedNameGroup.Targets == 1)
assert(unrelatedNameGroup.Targets[1] == unrelatedNameTarget)
