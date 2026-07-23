--!strict

local Packages = script.Parent.Parent.Parent.Parent.Parent.packages

local Map = require(Packages.mosaic.components.map)
local IntrinsicSubItems =
    require(Packages.mosaic.components.map.item.intrinsicSubItems)
local CreateItemFilter = require(Packages.mosaic.utils.filterItems)

local GetFlattenedDefinitionsList =
    IntrinsicSubItems.GetFlattenedDefinitionsList

type Item = Map.Item
type ItemFilter = (query: string?, items: { Item }) -> { Item }
type ItemFilterFactory = (items: { Item }) -> ItemFilter

local IntrinsicSearchTextsByType: { [string]: { string } } = {}

local function GetIntrinsicSearchTexts(item: Item): { string }
    local typeName = typeof(item.Value)
    local existingSearchTexts = IntrinsicSearchTextsByType[typeName]
    if existingSearchTexts then return existingSearchTexts end

    local intrinsicSubItems = GetFlattenedDefinitionsList(typeName)
    local searchTexts = table.create(#intrinsicSubItems) :: { string }

    for idx, subItem in intrinsicSubItems do
        searchTexts[idx] = subItem.Key
    end

    IntrinsicSearchTextsByType[typeName] = searchTexts
    return searchTexts
end

local function CreatePropertyItemFilter(items: { Item }): ItemFilter
    return CreateItemFilter(
        items,
        function(item: Item): string return item.Key end,
        GetIntrinsicSearchTexts
    )
end

return CreatePropertyItemFilter :: ItemFilterFactory
