--!strict

local Packages = script.Parent.Parent.Parent.Parent.Parent.packages

local Fusion = require(Packages.fusion)
local Value = Fusion.Value

local Mosaic = require(Packages.mosaic)
local IconButton = Mosaic.IconButton

local Map = require(Packages.mosaic.components.map)
type Item = Map.Item

local Assets = require(script.Parent.Parent.Parent.Parent.Parent.assets)

local Category = require(script.Parent.Parent.category)
type CategoryState = Category.State

local CommitAttribute = require(script.Parent.commitAttribute)

type AttributesMapProps = {
    OmitRbxAttributes: boolean
}

local RbxAttributePrefix = "RBX_"

local function GetAttributeName(item: Item): string
    local attributeName = item.Key
    assert(attributeName ~= nil, "Attribute map items must have keys.")
    return attributeName
end

local function ShouldOmitAttribute(
    attributeName: string,
    omitRbxAttributes: boolean
): boolean
    return omitRbxAttributes
        and string.sub(attributeName, 1, #RbxAttributePrefix)
            == RbxAttributePrefix
end

local function GetAttributeItems(
    instance: Instance,
    omitRbxAttributes: boolean
): { Item }
    local attributes = instance:GetAttributes()
    local attributeItems = {} :: { Item }

    local attributeIdx = 1
    for attributeName, attributeValue in attributes do
        if ShouldOmitAttribute(attributeName, omitRbxAttributes) then
            continue
        end

        attributeItems[attributeIdx] = {
            Key = attributeName,
            Value = attributeValue
        }

        attributeIdx += 1
    end

    return attributeItems
end

return function(
    scope: Fusion.Scope,
    outerScope: Fusion.Scope,
    collapsedStateScope: Fusion.Scope,
    instance: Instance,
    props: AttributesMapProps
): CategoryState
    local attributeItems = GetAttributeItems(
        instance,
        props.OmitRbxAttributes
    )
    local attributeItemIndices: { [string]: number } = {}
    local attributeItemsState = Value(scope, attributeItems)

    for itemIdx, item in attributeItems do
        attributeItemIndices[GetAttributeName(item)] = itemIdx
    end

    local refreshAttribute: (attributeName: string) -> (boolean, any?)

    local function makeAttributeWritable(item: Item, attributeName: string)
        item.Writable = true
        item.TrySetValue = function(value: any): (boolean, string?, any?)
            if item.Value == value then return true, nil, item.Value end

            local success, err = CommitAttribute(
                instance,
                attributeName,
                value
            )

            local _, savedValue = refreshAttribute(attributeName)
            return success, err, if success then savedValue else nil
        end
    end

    refreshAttribute = function(attributeName: string): (boolean, any?)
        if ShouldOmitAttribute(
            attributeName,
            props.OmitRbxAttributes
        ) then
            return false, nil
        end

        local itemIdx = attributeItemIndices[attributeName]
        local value = instance:GetAttribute(attributeName)

        if value == nil then
            if not itemIdx then return false, nil end

            table.remove(attributeItems, itemIdx)
            attributeItemIndices[attributeName] = nil

            for shiftedIdx = itemIdx, #attributeItems do
                local shiftedItem = attributeItems[shiftedIdx]
                attributeItemIndices[GetAttributeName(shiftedItem)] = shiftedIdx
            end
        elseif itemIdx then
            local item = attributeItems[itemIdx]
            if item.Value == value then return false, value end

            item.Value = value
        else
            local item = {
                Key = attributeName,
                Value = value
            }
            makeAttributeWritable(item, attributeName)
            table.insert(attributeItems, item)
            attributeItemIndices[attributeName] = #attributeItems
        end

        attributeItemsState:set(attributeItems)
        return true, value
    end

    for _, item in attributeItems do
        makeAttributeWritable(item, GetAttributeName(item))
    end

    table.insert(
        scope,
        instance.AttributeChanged:Connect(refreshAttribute)
    )

    return Category(scope, outerScope, collapsedStateScope, {
        Name = "Attributes",
        HeaderChildren = {
            IconButton(scope, {
                Image = Assets.Add
            })
        },
        Items = attributeItemsState,
        EmptyText = "No Attributes have been added yet."
    })
end
