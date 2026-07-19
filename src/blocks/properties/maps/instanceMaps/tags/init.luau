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

local CommitTag = require(script.Parent.commitTag)
local TagChanged = require(script.tagChanged)

local function CreateTagItem(instance: Instance, tag: string): Item
    local item: Item = {
        Value = tag,
        Writable = true
    }

    item.TrySetValue = function(newTag: string): (boolean, string?, any?)
        if newTag == tag then return true, nil, tag end

        local success, err = CommitTag(instance, tag, newTag)
        return success, err, if success then newTag else nil
    end

    return item
end

local function GetTagItems(instance: Instance): { Item }
    local tags = instance:GetTags()
    local tagItems = table.create(#tags) :: { Item }

    for idx, tag in tags do
        tagItems[idx] = CreateTagItem(instance, tag)
    end

    return tagItems
end

local function ApplyTagChange(
    instance: Instance,
    tagItems: { Item },
    tag: string,
    removed: boolean
)
    if not removed then
        table.insert(tagItems, CreateTagItem(instance, tag))
        return
    end

    for idx, tagItem in tagItems do
        if tagItem.Value ~= tag then continue end

        table.remove(tagItems, idx)
        return
    end
end

return function(
    scope: Fusion.Scope,
    outerScope: Fusion.Scope,
    collapsedStateScope: Fusion.Scope,
    instance: Instance
): CategoryState
    local tagItems = GetTagItems(instance)
    local tagItemsState = Value(scope, tagItems)

    table.insert(
        scope,
        TagChanged(instance, function(
            tag: string,
            removed: boolean
        )
            ApplyTagChange(instance, tagItems, tag, removed)

            -- Fusion treats mutable tables as dissimilar by design.
            tagItemsState:set(tagItems)
        end)
    )

    return Category(scope, outerScope, collapsedStateScope, {
        Name = "Tags",
        HeaderChildren = {
            IconButton(scope, {
                Image = Assets.Add
            })
        },
        Items = tagItemsState,
        EmptyText = "No Tags have been added yet."
    })
end
