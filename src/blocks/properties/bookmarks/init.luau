--!strict

local Packages = script.Parent.Parent.Parent.packages

local Fusion = require(Packages.fusion)
local Value = Fusion.Value

local CreateKey = require(script.createKey)

type Store = {
    Plugin: Plugin,
    States: { [string]: Fusion.Value<boolean> }
}

local StoresByScope: { [Fusion.Scope]: Store } = {}

local function GetPlugin(): Plugin
    local plugin = script:FindFirstAncestorOfClass("Plugin")
    assert(plugin, "Bookmarks must be created from inside a Plugin")
    return plugin
end

local function GetStore(scope: Fusion.Scope): Store
    local existingStore = StoresByScope[scope]
    if existingStore then return existingStore end

    local store: Store = {
        Plugin = GetPlugin(),
        States = {}
    }
    StoresByScope[scope] = store

    table.insert(scope, function()
        StoresByScope[scope] = nil
    end)

    return store
end

local function GetState(
    scope: Fusion.Scope,
    bookmarkKey: string
): Fusion.Value<boolean>
    local store = GetStore(scope)
    local existingState = store.States[bookmarkKey]
    if existingState then return existingState end

    local success, storedValue =
        pcall(store.Plugin.GetSetting, store.Plugin, bookmarkKey)
    local bookmarkedState = Value(
        scope,
        success and storedValue == true
    )
    store.States[bookmarkKey] = bookmarkedState

    return bookmarkedState
end

local function Set(
    scope: Fusion.Scope,
    bookmarkKey: string,
    bookmarked: boolean
): (boolean, string?)
    local store = GetStore(scope)
    local success, err = pcall(
        store.Plugin.SetSetting,
        store.Plugin,
        bookmarkKey,
        bookmarked
    )
    if not success then return false, tostring(err) end

    GetState(scope, bookmarkKey):set(bookmarked)
    return true, nil
end

return {
    CreateKey = CreateKey,
    GetState = GetState,
    Set = Set
}
