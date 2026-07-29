--!strict

local Packages = script.Parent.Parent.Parent.Parent.Parent.packages

local Fusion = require(Packages.fusion)
local Peek = Fusion.peek

local Map = require(Packages.mosaic.components.map)
local IntrinsicSubItems =
    require(Packages.mosaic.components.map.item.intrinsicSubItems)
local CreateItemFilter = require(Packages.mosaic.utils.filterItems)

local GetFlattenedDefinitionsList =
    IntrinsicSubItems.GetFlattenedDefinitionsList

type SearchableItem = {
    Key: string,
    Value: any?,
    ValueType: Map.ValueType?
}
type ItemFilter = (
    query: string?,
    items: { SearchableItem }
) -> { SearchableItem }
type ItemFilterFactory = (items: { SearchableItem }) -> ItemFilter

local IntrinsicSearchTextsByType: { [string]: { string } } = {}

local function GetIntrinsicSearchTexts(item: SearchableItem): { string }
    local valueType = item.ValueType
    if type(valueType) == "function" then return {} end

    local typeName: string
    if type(valueType) == "string" then
        typeName = valueType
    else
        local value = item.Value
        if value == nil then return {} end
        typeName = typeof(Peek(value))
    end

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

local function CreatePropertyItemFilter(
    items: { SearchableItem }
): ItemFilter
    return CreateItemFilter(
        items,
        function(item: SearchableItem): string return item.Key end,
        GetIntrinsicSearchTexts
    )
end

return CreatePropertyItemFilter :: ItemFilterFactory
