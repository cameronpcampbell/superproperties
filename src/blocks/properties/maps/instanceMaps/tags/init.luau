--!strict

local Packages = script.Parent.Parent.Parent.Parent.Parent.packages

local Fusion = require(Packages.fusion)
local Value, OnEvent = Fusion.Value, Fusion.OnEvent

local Mosaic = require(Packages.mosaic)
local IconButton = Mosaic.IconButton

local Map = require(Packages.mosaic.components.map)
type Item = Map.Item

local Assets = require(script.Parent.Parent.Parent.Parent.Parent.assets)

local Category = require(script.Parent.Parent.category)
type CategoryState = Category.State

local CommitRemoveTag = require(script.Parent.commitRemoveTag)
local TagChanged = require(script.tagChanged)

type TagRemovedCallback = (tag: string) -> ()

local function CreateTagItem(
    scope: Fusion.Scope,
    instance: Instance,
    tag: string,
    onTagRemoved: TagRemovedCallback
): Item
    return {
        Value = tag,
        Writable = false,
        ValueChildren = {
            IconButton(scope, {
                Image = Assets.Cross,

                [OnEvent "MouseButton1Click"] = function()
                    local success, err = CommitRemoveTag(instance, tag)
                    if not success then
                        warn(`Could not remove tag {tag}: {err}`)
                        return
                    end

                    onTagRemoved(tag)
                end
            })
        }
    }
end

local function GetTagItems(
    scope: Fusion.Scope,
    instance: Instance,
    onTagRemoved: TagRemovedCallback
): { Item }
    local tags = instance:GetTags()
    local tagItems = table.create(#tags) :: { Item }

    for idx, tag in tags do
        tagItems[idx] = CreateTagItem(
            scope,
            instance,
            tag,
            onTagRemoved
        )
    end

    return tagItems
end

local function ApplyTagChange(
    scope: Fusion.Scope,
    instance: Instance,
    tagItems: { Item },
    onTagRemoved: TagRemovedCallback,
    tag: string,
    removed: boolean
): boolean
    if not removed then
        table.insert(tagItems, CreateTagItem(
            scope,
            instance,
            tag,
            onTagRemoved
        ))
        return true
    end

    for idx, tagItem in tagItems do
        if tagItem.Value ~= tag then continue end

        table.remove(tagItems, idx)
        return true
    end

    return false
end

return function(
    scope: Fusion.Scope,
    outerScope: Fusion.Scope,
    collapsedStateScope: Fusion.Scope,
    instance: Instance
): CategoryState
    local publishTagChange: (tag: string, removed: boolean) -> ()
    local function onTagRemoved(tag: string)
        publishTagChange(tag, true)
    end

    local tagItems = GetTagItems(scope, instance, onTagRemoved)
    local tagItemsState = Value(scope, tagItems)

    publishTagChange = function(tag: string, removed: boolean)
        local changed = ApplyTagChange(
            scope,
            instance,
            tagItems,
            onTagRemoved,
            tag,
            removed
        )
        if not changed then return end

        -- Fusion treats mutable tables as dissimilar by design.
        tagItemsState:set(tagItems)
    end

    table.insert(
        scope,
        TagChanged(instance, publishTagChange)
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
