--!strict

local Packages = script.Parent.Parent.Parent.Parent
local Fusion = require(Packages.fusion)

export type Mode = "Shared" | "Scoped"

--[[
    Shared:
        Returns the nearest inherited value. If none exists, creates a value
        owned by the current scope. Mutations are visible to every scope which
        shares that value.

    Scoped:
        Returns a value owned by the exact scope. If necessary, creates one
        which shadows the inherited value. Changes never affect parent data.
]]
export type Options<T> = {
    -- "Shared" is the default mode.
    Mode: Mode?,

    -- Creates the value when this scope needs to own one. In Scoped mode, the
    -- nearest parent value is provided so the new value can derive from it.
    -- When omitted, an empty table is created.
    Create: ((parent: T?) -> T)?,

    -- Runs when the scope which owns the value is destroyed.
    Destroy: ((value: T) -> ())?,

    -- Relinks an existing scoped value when its nearest parent value is
    -- created after it.
    UpdateParent: ((value: T, parent: T) -> ())?,
}

type Entry = {
    Value: any,
    Destroy: ((value: any) -> ())?,
    UpdateParent: ((value: any, parent: any) -> ())?,
}

type Context = {
    Parent: Context?,
    Children: { [Context]: true },
    Values: { [string]: Entry },
}

local CONTEXT_KEY = {}

local ContextsByScope: { [Fusion.Scope]: Context } = {}

local function InstallContext(scope: Fusion.Scope, context: Context)
    local scopeMetatable = getmetatable(scope)
    assert(
        typeof(scopeMetatable) == "table",
        "Scoped data requires a Fusion scope with a table metatable"
    )

    local scopeMethods = (scopeMetatable :: any).__index
    assert(
        typeof(scopeMethods) == "table",
        "Scoped data requires a Fusion scope with a table __index"
    )

    local contextMethods = table.clone(scopeMethods)
    contextMethods[CONTEXT_KEY] = context

    local contextMetatable = table.clone(scopeMetatable :: any)
    contextMetatable.__index = contextMethods

    setmetatable(scope, contextMetatable)
end

local function CreateContext(
    scope: Fusion.Scope,
    parent: Context?
): Context
    local context: Context = {
        Parent = parent,
        Children = {},
        Values = {},
    }

    if parent then parent.Children[context] = true end

    ContextsByScope[scope] = context
    InstallContext(scope, context)

    table.insert(scope, function()
        ContextsByScope[scope] = nil

        local currentParent = context.Parent
        if currentParent then currentParent.Children[context] = nil end

        for child in context.Children do
            child.Parent = nil
        end

        for _, entry in context.Values do
            local destroy = entry.Destroy
            if destroy then destroy(entry.Value) end
        end

        table.clear(context.Children)
        table.clear(context.Values)
        context.Parent = nil
    end)

    return context
end

local function FindEntry(context: Context?, key: string): Entry?
    local current = context

    while current do
        local entry = current.Values[key]
        if entry then return entry end

        current = current.Parent
    end

    return nil
end

local function UpdateDescendantParents(
    context: Context,
    key: string,
    value: any
)
    for child in context.Children do
        local entry = child.Values[key]
        if entry then
            local updateParent = entry.UpdateParent
            if updateParent then updateParent(entry.Value, value) end
        else
            UpdateDescendantParents(child, key, value)
        end
    end
end

local function ScopedData<T>(
    scope: Fusion.Scope,
    key: string,
    options: Options<T>?
): T
    local ownContext = ContextsByScope[scope]
    local inheritedContext =
        if ownContext then ownContext
        else (scope :: any)[CONTEXT_KEY] :: Context?

    local mode = if options then options.Mode else nil

    if mode ~= "Scoped" then
        local inheritedEntry = FindEntry(inheritedContext, key)
        if inheritedEntry then return inheritedEntry.Value end
    end

    if not ownContext then
        ownContext = CreateContext(scope, inheritedContext)
    end

    local ownEntry = ownContext.Values[key]
    if ownEntry then return ownEntry.Value end

    local parentEntry = FindEntry(ownContext.Parent, key)
    local parentValue =
        if parentEntry then parentEntry.Value :: T
        else nil

    local create = if options then options.Create else nil
    local value =
        if create then create(parentValue)
        else {} :: any

    ownContext.Values[key] = {
        Value = value,
        Destroy = if options then options.Destroy else nil,
        UpdateParent = if options then options.UpdateParent else nil,
    }
    UpdateDescendantParents(ownContext, key, value)

    return value
end

return ScopedData
