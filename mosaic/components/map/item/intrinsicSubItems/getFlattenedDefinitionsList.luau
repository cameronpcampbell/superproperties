--!strict

local Types = require(script.Parent.Parent.Parent.types)

local DefinitionsByType = require(script.Parent.definitions)

local EmptyItems = table.freeze({}) :: Types.IntrinsicItems
local FlattenedDefinitionsByType: { [string]: Types.IntrinsicItems } = {}

local function AppendFlattenedItems(
    items: Types.IntrinsicItems,
    flattenedItems: Types.IntrinsicItems
)
    for _, item in items do
        table.insert(flattenedItems, item)

        local subItems = item.SubItems
        if subItems then
            AppendFlattenedItems(subItems, flattenedItems)
        end
    end
end

for typeName, items in DefinitionsByType do
    local flattenedItems = {} :: Types.IntrinsicItems
    AppendFlattenedItems(items, flattenedItems)
    FlattenedDefinitionsByType[typeName] = table.freeze(flattenedItems)
end

return function(typeName: string): Types.IntrinsicItems
    return FlattenedDefinitionsByType[typeName] or EmptyItems
end
