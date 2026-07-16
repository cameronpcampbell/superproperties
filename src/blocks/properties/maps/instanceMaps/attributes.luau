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

type AttributesMapProps = {
    OmitRbxAttributes: boolean
}

local RbxAttributePrefix = "RBX_"

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
        attributeItemIndices[item.Key] = itemIdx
    end

    local function refreshAttribute(attributeName: string)
        if ShouldOmitAttribute(
            attributeName,
            props.OmitRbxAttributes
        ) then
            return
        end

        local itemIdx = attributeItemIndices[attributeName]
        local value = instance:GetAttribute(attributeName)

        if value == nil then
            if not itemIdx then return end

            table.remove(attributeItems, itemIdx)
            attributeItemIndices[attributeName] = nil

            for shiftedIdx = itemIdx, #attributeItems do
                attributeItemIndices[attributeItems[shiftedIdx].Key] =
                    shiftedIdx
            end
        elseif itemIdx then
            local item = attributeItems[itemIdx]
            if item.Value == value then return end

            item.Value = value
        else
            table.insert(attributeItems, {
                Key = attributeName,
                Value = value
            })
            attributeItemIndices[attributeName] = #attributeItems
        end

        attributeItemsState:set(attributeItems)
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
