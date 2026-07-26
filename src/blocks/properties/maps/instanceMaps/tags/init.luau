--!strict

local CollectionService = game:GetService("CollectionService")

local Packages = script.Parent.Parent.Parent.Parent.Parent.packages

local Fusion = require(Packages.fusion)
local Computed, Observer, OnEvent, Peek, Value =
    Fusion.Computed, Fusion.Observer,
    Fusion.OnEvent, Fusion.peek, Fusion.Value

local Mosaic = require(Packages.mosaic)
local IconButton, PopoverFocus, SelectMenu =
    Mosaic.IconButton, Mosaic.PopoverFocus, Mosaic.SelectMenu

local Map = require(Packages.mosaic.components.map)
type Item = Map.Item

local Assets = require(script.Parent.Parent.Parent.Parent.Parent.assets)

local Category = require(script.Parent.Parent.category)
type CategoryState = Category.State

local CommitAddTag = require(script.commitAddTag)
local CommitRemoveTag = require(script.commitRemoveTag)
local TagChanged = require(script.tagChanged)

type TagOption = {
    Tag: string,
    Label: string
}

local MenuGap = 4
local MenuMaxHeight = 180
local MenuRightInset = 6

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

return function(
    scope: Fusion.Scope,
    outerScope: Fusion.Scope,
    collapsedStateScope: Fusion.Scope,
    instances: { Instance }
): CategoryState
    local tagItemsState = Value<<{ Item }>>(scope, {})
    local itemChildrenScope = Fusion.innerScope(scope)
    local refreshTagItems: () -> ()

    refreshTagItems = function()
        Fusion.doCleanup(itemChildrenScope)
        itemChildrenScope = Fusion.innerScope(scope)

        local instancesByTag: { [string]: { Instance } } = {}
        for _, instance in instances do
            for _, tag in instance:GetTags() do
                local tagInstances = instancesByTag[tag]
                if not tagInstances then
                    tagInstances = {}
                    instancesByTag[tag] = tagInstances
                end
                table.insert(tagInstances, instance)
            end
        end

        local tagItems = {} :: { Item }
        for tag, tagInstances in instancesByTag do
            table.insert(tagItems, {
                Key = tag,
                DisplayAsWritable = true,
                KeyChildren = {
                    IconButton(itemChildrenScope, {
                        Image = Assets.Cross,

                        [OnEvent "MouseButton1Click"] = function()
                            local success, err =
                                CommitRemoveTag(tagInstances, tag)
                            refreshTagItems()

                            if not success then
                                warn(`Could not remove tag {tag}: {err}`)
                            end
                        end
                    })
                }
            })
        end

        tagItemsState:set(tagItems)
    end

    refreshTagItems()
    local allTagsState = Value(scope, GetAllTags())
    local menuOpenState = Value(scope, false)
    local menuElevatedState = Value(scope, false)
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

    local function refreshAllTags()
        allTagsState:set(GetAllTags())
    end

    table.insert(scope, CollectionService.TagAdded:Connect(refreshAllTags))
    table.insert(scope, CollectionService.TagRemoved:Connect(refreshAllTags))

    for _, instance in instances do
        table.insert(
            scope,
            TagChanged(instance, function(
                _tag: string,
                _removed: boolean
            )
                refreshTagItems()
            end)
        )
    end

    local selectMenu: GuiObject
    local addButton: GuiObject
    local scopeAlive = true
    local focusSearch: () -> ()

    table.insert(scope, function()
        scopeAlive = false
    end)

    local function getSearchTextBox(): TextBox?
        local search = selectMenu:FindFirstChild("Search")
        return if search and search:IsA("TextBox") then search else nil
    end

    local function deferSelectedIdxReset(observedIdx: number?)
        if observedIdx == nil then return end

        task.defer(function()
            if not scopeAlive then return end
            if Peek<<number?>>(selectedIdxState) ~= observedIdx then return end

            selectedIdxState:set(nil)
        end)
    end

    local function hideMenu()
        deferSelectedIdxReset(Peek<<number?>>(selectedIdxState))
        menuOpenState:set(false)
    end

    local popoverFocus = PopoverFocus(scope, {
        GetInteractionRoots = function(): { GuiObject }
            return { selectMenu, addButton }
        end,
        OnFocusChanged = function(isFocused: boolean)
            if isFocused then
                -- Elevate the map and its header before rendering the menu.
                menuElevatedState:set(true)
                menuOpenState:set(true)
                focusSearch()
            else
                hideMenu()
            end
        end,
        Name = "TagsMenuFocusTarget"
    })

    focusSearch = function()
        task.defer(function()
            if not scopeAlive then return end
            if not Peek<<boolean>>(popoverFocus.State) then return end

            local search = getSearchTextBox()
            if search then popoverFocus.CaptureChild(search) end
        end)
    end

    local function closeMenu()
        popoverFocus.Release()
    end

    local function addTag(tag: string): boolean
        if tag == "" then return false end

        local allHaveTag = true
        for _, instance in instances do
            if instance:HasTag(tag) then continue end
            allHaveTag = false
            break
        end
        if allHaveTag then
            closeMenu()
            return true
        end

        local success, err = CommitAddTag(instances, tag)
        if not success then
            warn(`Could not add tag {tag}: {err}`)
            deferSelectedIdxReset(Peek<<number?>>(selectedIdxState))
            focusSearch()
            return false
        end

        refreshTagItems()
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
        SearchPlaceholderText = "Search for or create a tag.",
        SelectedIdx = selectedIdxState,
        Width = UDim.new(.5, 0),
        MaxHeight = MenuMaxHeight,
        Position = UDim2.new(1, -MenuRightInset, 1, MenuGap),
        AnchorPoint = Vector2.new(1, 0),
        Visible = menuOpenState,
        Interactable = menuOpenState,
        OutRenderVisible = menuElevatedState,
        EmptyText = "",
        ZIndex = 4,

        OnSearchFocused = function()
            popoverFocus.ChildFocused(getSearchTextBox())
        end,

        OnSearchFocusLost = function(
            enterPressed: boolean,
            inputThatCausedFocusLoss: InputObject?
        )
            if enterPressed then
                local candidate = Trim(Peek<<string>>(searchState))
                if candidate ~= "" then
                    addTag(candidate)
                else
                    closeMenu()
                end
                return
            end

            popoverFocus.ChildFocusLost(inputThatCausedFocusLoss)
        end
    }) :: GuiObject

    return Category(scope, outerScope, collapsedStateScope, {
        Name = "Tags",
        HeaderChildren = function(
            headerScope: Fusion.Scope,
            headerColors: Map.HeaderColors
        ): { Fusion.Child }
            addButton = IconButton(headerScope, {
                Image = Assets.Add,
                ImageColor3 = headerColors.ForegroundColor3,

                [OnEvent "MouseButton1Click"] = function()
                    if Peek<<boolean>>(popoverFocus.State) then
                        closeMenu()
                        return
                    end

                    selectedIdxState:set(nil)
                    searchState:set("")
                    refreshAllTags()
                    popoverFocus.Capture()
                end
            }) :: GuiObject

            return { addButton }
        end,
        HeaderOverlay = ({
            selectMenu,
            popoverFocus.Target
        } :: any),
        ShowOnTop = menuElevatedState,
        Items = tagItemsState,
        EmptyText = "No Tags have been added yet."
    })
end
