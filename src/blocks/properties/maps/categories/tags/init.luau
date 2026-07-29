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

local Bookmarks = require(script.Parent.Parent.Parent.bookmarks)
local Category = require(script.Parent.Parent.category)
type CategoryState = Category.State
type RowDescriptor = Category.RowDescriptor

local CommitAddTag = require(script.commitAddTag)
local CommitRemoveTag = require(script.commitRemoveTag)
local TagChanged = require(script.tagChanged)
local TagOptions = require(script.tagOptions)
type TagOption = TagOptions.Option
type TagSet = TagOptions.TagSet

local MenuGap = 4
local MenuMaxHeight = 180
local MenuRightInset = 6
local BookmarkCategoryName = "Tags"
local BookmarkOwnerName = "CollectionService"

local function GetAllTags(): { string }
    local tags = CollectionService:GetAllTags() :: { string }
    table.sort(tags)
    return tags
end

return function(
    scope: Fusion.Scope,
    outerScope: Fusion.Scope,
    collapsedStateScope: Fusion.Scope,
    instances: { Instance }
): CategoryState
    local tagRowsState = Value<<{ RowDescriptor }>>(scope, {})
    local commonTagsState = Value<<TagSet>>(scope, {})
    local refreshTagItems: () -> ()
    local refreshEventRevision = 0
    local handledRefreshEventRevision = 0
    local refreshPending = false
    local tagsAlive = true
    local syncTagSnapshotsByInstance: {
        [Instance]: (TagSet) -> ()
    } = {}

    refreshTagItems = function()
        local instancesByTag: { [string]: { Instance } } = {}
        for _, instance in instances do
            local instanceTags = {} :: TagSet
            for _, tag in instance:GetTags() do
                instanceTags[tag] = true
                local tagInstances = instancesByTag[tag]
                if not tagInstances then
                    tagInstances = {}
                    instancesByTag[tag] = tagInstances
                end
                table.insert(tagInstances, instance)
            end

            local syncTagSnapshot =
                syncTagSnapshotsByInstance[instance]
            if syncTagSnapshot then
                syncTagSnapshot(instanceTags)
            end
        end

        local tagRows = {} :: { RowDescriptor }
        local commonTags = {} :: TagSet
        for tag, tagInstances in instancesByTag do
            if #tagInstances == #instances then
                commonTags[tag] = true
            end

            local usedTag = tag
            local usedTagInstances = tagInstances
            local bookmarkKey = Bookmarks.CreateKey(
                BookmarkCategoryName,
                BookmarkOwnerName,
                usedTag
            )

            table.insert(tagRows, {
                Id = bookmarkKey,
                Key = usedTag,
                BookmarkKey = bookmarkKey,
                Hydrate = function(
                    _hydrationScope: Fusion.Scope
                ): Item
                    return ({
                        Key = usedTag,
                        BookmarkKey = bookmarkKey,
                        DisplayAsWritable = true,
                        KeyChildren = function(
                            childScope: Fusion.Scope<typeof(Fusion)>,
                            transparency: Fusion.UsedAs<number>
                        ): { Fusion.Child }
                            return {
                                IconButton(childScope, {
                                    Image = Assets.Cross,
                                    ImageTransparency = transparency,

                                    [OnEvent "MouseButton1Click"] = function()
                                        local success, err =
                                            CommitRemoveTag(
                                                usedTagInstances,
                                                usedTag
                                            )
                                        refreshTagItems()

                                        if not success then
                                            warn(
                                                `Could not remove tag {usedTag}: {err}`
                                            )
                                        end
                                    end
                                })
                            }
                        end
                    } :: any) :: Item
                end
            })
        end

        commonTagsState:set(commonTags)
        tagRowsState:set(tagRows)
        handledRefreshEventRevision = refreshEventRevision
    end

    local function queueRefreshTagItems()
        refreshEventRevision += 1
        if refreshPending then return end
        refreshPending = true

        task.defer(function()
            refreshPending = false
            if not tagsAlive
                or handledRefreshEventRevision
                    == refreshEventRevision
            then
                return
            end

            refreshTagItems()
        end)
    end

    refreshTagItems()
    table.insert(scope, function()
        tagsAlive = false
    end)
    local allTagsState = Value(scope, {} :: { string })
    local menuOpenState = Value(scope, false)
    local menuElevatedState = Value(scope, false)
    local searchState = Value(scope, "")
    local selectedIdxState = Value<<number?>>(scope, nil)
    local menuOptions = Computed(scope, function(use): { TagOption }
        if not use<<boolean>>(menuElevatedState) then
            return {} :: { TagOption }
        end

        return TagOptions.Create(
            use<<{ string }>>(allTagsState),
            use<<TagSet>>(commonTagsState),
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

    Observer(scope, menuElevatedState):onChange(function()
        if Peek<<boolean>>(menuElevatedState) then return end
        allTagsState:set({})
    end)

    local function refreshAllTags(force: boolean?)
        if force ~= true
            and not Peek<<boolean>>(menuOpenState)
        then
            return
        end

        allTagsState:set(GetAllTags())
    end

    table.insert(
        scope,
        CollectionService.TagAdded:Connect(function()
            refreshAllTags()
        end)
    )
    table.insert(
        scope,
        CollectionService.TagRemoved:Connect(function()
            refreshAllTags()
        end)
    )

    for _, instance in instances do
        local disconnect, syncTagSnapshot =
            TagChanged(instance, function(
                _tag: string,
                _removed: boolean
            )
                queueRefreshTagItems()
            end)
        syncTagSnapshotsByInstance[instance] = syncTagSnapshot
        table.insert(
            scope,
            disconnect
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
        SortOrder = Enum.SortOrder.Name,
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
                local candidate = TagOptions.Trim(
                    Peek<<string>>(searchState)
                )
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
            headerScope: Fusion.Scope<typeof(Fusion)>,
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
                    refreshAllTags(true)
                    refreshTagItems()
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
        Rows = tagRowsState,
        Bookmarkable = true,
        EmptyText = "No Tags have been added yet."
    })
end
