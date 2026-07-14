--!strict

local Packages = script.Parent.Parent.Parent.Parent.Parent.packages

local Fusion = require(Packages.fusion)
local Value = Fusion.Value

local Map = require(Packages.mosaic.components.map)
type Item = Map.Item

local Category = require(script.Parent.Parent.category)
type CategoryState = Category.State

type AttributesMapProps = {
    OmitRbxAttributes: boolean
}

local RbxAttributePrefix = "RBX_"

local function GetAttributeItems(
    instance: Instance,
    omitRbxAttributes: boolean
): { Item }
    local attributes = instance:GetAttributes()
    local attributeItems = {} :: { Item }

    local attributeIdx = 1
    for attributeName, attributeValue in attributes do
        if omitRbxAttributes
            and string.sub(attributeName, 1, #RbxAttributePrefix)
                == RbxAttributePrefix
        then
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
    local attributeItems = Value(scope, {} :: { Item })

    local function refreshAttributeItems()
        attributeItems:set(GetAttributeItems(
            instance,
            props.OmitRbxAttributes
        ))
    end

    table.insert(
        scope,
        instance.AttributeChanged:Connect(refreshAttributeItems)
    )

    refreshAttributeItems()

    return Category(scope, outerScope, collapsedStateScope, {
        Name = "Attributes",
        Items = attributeItems,
        EmptyText = "No Attributes have been added yet."
    })
end
