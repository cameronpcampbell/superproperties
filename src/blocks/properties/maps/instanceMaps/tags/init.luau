--!strict

local CollectionService = game:GetService("CollectionService")

local Packages = script.Parent.Parent.Parent.Parent.Parent.packages

local Fusion = require(Packages.fusion)
local Computed, Observer, OnEvent, Peek, Value =
    Fusion.Computed, Fusion.Observer,
    Fusion.OnEvent, Fusion.peek, Fusion.Value

local Mosaic = require(Packages.mosaic)
local IconButton, SelectMenu = Mosaic.IconButton, Mosaic.SelectMenu

local Map = require(Packages.mosaic.components.map)
type Item = Map.Item

local Assets = require(script.Parent.Parent.Parent.Parent.Parent.assets)

local Category = require(script.Parent.Parent.category)
type CategoryState = Category.State

local CommitAddTag = require(script.Parent.commitAddTag)
local CommitRemoveTag = require(script.Parent.commitRemoveTag)
local TagChanged = require(script.tagChanged)

type TagRemovedCallback = (tag: string) -> ()
type TagOption = {
    Tag: string,
    Label: string
}

local MenuGap = 4
local MenuMaxHeight = 180
local MenuRightInset = 6

local function IsPointInside(guiObject: GuiObject, point: Vector3): boolean
    local topLeft = guiObject.AbsolutePosition
    local bottomRight = topLeft + guiObject.AbsoluteSize

    return point.X >= topLeft.X
        and point.X <= bottomRight.X
        and point.Y >= topLeft.Y
        and point.Y <= bottomRight.Y
end

local function Trim(text: string): string
    return text:match("^%s*(.-)%s*$") or ""
end

local function GetAllTags(): { string }
    local tags = CollectionService:GetAllTags() :: { string }
    table.sort(tags)
    return tags
end

local function CreateTagOptions(
    allTags: { string },
    query: string
): { TagOption }
    local candidate = Trim(query)
    local exactMatch = table.find(allTags, candidate) ~= nil
    local hasCreateOption = candidate ~= "" and not exactMatch
    local options = table.create(
        #allTags + (if hasCreateOption then 1 else 0)
    ) :: { TagOption }
    local optionIdx = 1

    if hasCreateOption then
        options[optionIdx] = {
            Tag = candidate,
            Label = `Create tag: {candidate}`
        }
        optionIdx += 1
    end

    for _, tag in allTags do
        options[optionIdx] = {
            Tag = tag,
            Label = tag
        }
        optionIdx += 1
    end

    return options
end

local function CreateTagItem(
    scope: Fusion.Scope,
    instance: Instance,
    tag: string,
    onTagRemoved: TagRemovedCallback
): Item
    return {
        Value = tag,
        Writable = false,
        DisplayAsWritable = true,
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
    for idx, tagItem in tagItems do
        if tagItem.Value ~= tag then continue end

        if not removed then return false end

        table.remove(tagItems, idx)
        return true
    end

    if removed then return false end

    table.insert(tagItems, CreateTagItem(
        scope,
        instance,
        tag,
        onTagRemoved
    ))
    return true
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
    local allTagsState = Value(scope, GetAllTags())
    local menuOpenState = Value(scope, false)
    local searchState = Value(scope, "")
    local selectedIdxState = Value<<number?>>(scope, nil)
    local menuOptions = Computed(scope, function(use): { TagOption }
        return CreateTagOptions(
            use<<{ string }>>(allTagsState),
            use<<string>>(searchState)
        )
    end)
    local menuLabels = Computed(scope, function(use): { string }
        local options = use<<{ TagOption }>>(menuOptions)
        local labels = table.create(#options) :: { string }

        for idx, option in options do
            labels[idx] = option.Label
        end

        return labels
    end)

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

    local function refreshAllTags()
        allTagsState:set(GetAllTags())
    end

    table.insert(scope, CollectionService.TagAdded:Connect(refreshAllTags))
    table.insert(scope, CollectionService.TagRemoved:Connect(refreshAllTags))

    table.insert(
        scope,
        TagChanged(instance, publishTagChange)
    )

    local selectMenu: GuiObject
    local addButton: GuiObject
    local scopeAlive = true
    local isSearchFocused = false

    table.insert(scope, function()
        scopeAlive = false
    end)

    local function getSearchTextBox(): TextBox?
        local search = selectMenu:FindFirstChild("Search")
        return if search and search:IsA("TextBox") then search else nil
    end

    local function focusSearch()
        task.defer(function()
            if not scopeAlive or not Peek<<boolean>>(menuOpenState) then
                return
            end

            local search = getSearchTextBox()
            if search and not search:IsFocused() then search:CaptureFocus() end
        end)
    end

    local function deferSelectedIdxReset(observedIdx: number?)
        if observedIdx == nil then return end

        task.defer(function()
            if not scopeAlive then return end
            if Peek<<number?>>(selectedIdxState) ~= observedIdx then return end

            selectedIdxState:set(nil)
        end)
    end

    local function closeMenu()
        deferSelectedIdxReset(Peek<<number?>>(selectedIdxState))
        menuOpenState:set(false)
        searchState:set("")

        local search = getSearchTextBox()
        if search and search:IsFocused() then search:ReleaseFocus(false) end
    end

    local function addTag(tag: string): boolean
        if tag == "" then return false end

        if instance:HasTag(tag) then
            closeMenu()
            return true
        end

        local success, err = CommitAddTag(instance, tag)
        if not success then
            warn(`Could not add tag {tag}: {err}`)
            deferSelectedIdxReset(Peek<<number?>>(selectedIdxState))
            focusSearch()
            return false
        end

        publishTagChange(tag, false)
        refreshAllTags()
        closeMenu()
        return true
    end

    Observer(scope, selectedIdxState):onChange(function()
        local selectedIdx = Peek<<number?>>(selectedIdxState)
        if selectedIdx == nil then return end

        local option = Peek<<{ TagOption }>>(menuOptions)[selectedIdx]
        if not option then
            deferSelectedIdxReset(selectedIdx)
            return
        end

        addTag(option.Tag)
    end)

    selectMenu = SelectMenu(scope, {
        Items = menuLabels,
        EnableSearch = true,
        SearchState = searchState,
        SearchPlaceholderText = "Search for or create a tag",
        SelectedIdx = selectedIdxState,
        Width = UDim.new(.5, 0),
        MaxHeight = MenuMaxHeight,
        Position = UDim2.new(1, -MenuRightInset, 1, MenuGap),
        AnchorPoint = Vector2.new(1, 0),
        Visible = menuOpenState,
        Interactable = menuOpenState,
        EmptyText = "",
        ZIndex = 4,

        OnSearchFocused = function()
            isSearchFocused = true
            menuOpenState:set(true)
        end,

        OnSearchFocusLost = function(
            enterPressed: boolean,
            inputThatCausedFocusLoss: InputObject?
        )
            isSearchFocused = false

            if enterPressed then
                local candidate = Trim(Peek<<string>>(searchState))
                if candidate ~= "" then
                    addTag(candidate)
                else
                    closeMenu()
                end
                return
            end

            if inputThatCausedFocusLoss ~= nil and (
                IsPointInside(selectMenu, inputThatCausedFocusLoss.Position)
                or IsPointInside(addButton, inputThatCausedFocusLoss.Position)
            ) then
                task.defer(function()
                    if Peek<<boolean>>(menuOpenState)
                        and not isSearchFocused
                    then
                        focusSearch()
                    end
                end)
                return
            end

            closeMenu()
        end
    }) :: GuiObject

    addButton = IconButton(scope, {
        Image = Assets.Add,

        [OnEvent "MouseButton1Click"] = function()
            if Peek<<boolean>>(menuOpenState) then
                closeMenu()
                return
            end

            selectedIdxState:set(nil)
            searchState:set("")
            refreshAllTags()
            menuOpenState:set(true)
            focusSearch()
        end
    }) :: GuiObject

    return Category(scope, outerScope, collapsedStateScope, {
        Name = "Tags",
        HeaderChildren = ({
            addButton
        } :: { Fusion.Child }),
        HeaderOverlay = selectMenu,
        ShowOnTop = menuOpenState,
        Items = tagItemsState,
        EmptyText = "No Tags have been added yet."
    })
end
