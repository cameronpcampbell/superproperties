--!strict

local Packages = script.Parent.Parent.Parent.packages

local Fusion = require(Packages.fusion)
local Children, Computed, Observer, Peek, Value =
    Fusion.Children, Fusion.Computed, Fusion.Observer,
    Fusion.peek, Fusion.Value

local Mosaic = require(Packages.mosaic)
local Text = Mosaic.Text
local VirtualMapScrollable =
    require(Packages.mosaic.components.virtualMapScrollable)
type MapShape = VirtualMapScrollable.MapShape

local Category = require(script.category)
type CategoryDetail = Category.Detail
type CategoryModel = Category.Model
type CategoryState = Category.State

type RenderedMaps = {
    Shape: { MapShape },
    Detail: { CategoryDetail }
}

type CategoryGeneration = {
    Scope: Fusion.Scope,
    States: { CategoryState },
    Alive: boolean,
    Revision: number
}

type PropertiesMapsProps = {
    SelectedInstancesValue: Fusion.Value<{ Instance }>,
    Active: Fusion.UsedAs<boolean>?,
    OmitRbxAttributes: boolean?,
    TintHeaders: Fusion.UsedAs<boolean>,
    ShowNonScriptableProperties: Fusion.UsedAs<boolean>
}

local ExtraCategories = require(script.extraCategories)
local GetBookmarkButtonVisualState =
    require(script.Parent.getBookmarkButtonVisualState)
local GetBookmarksOnlyState =
    require(script.Parent.getBookmarksOnlyState)
local GetFilterState = require(script.Parent.getFilterState)
local Categories = require(script.categories)

local function TableBulkInsert<T>(target: { T }, source: { T })
    table.move(source, 1, #source, #target + 1, target)
end

local function CreateEmptyMessage(
    scope: Fusion.Scope,
    message: string
): Fusion.Child
    return Text(scope, {
        Text = message,
        Variant = "Secondary",
        Size = UDim2.fromScale(1, 1),
        AutomaticSize = Enum.AutomaticSize.None,
        TextXAlignment = Enum.TextXAlignment.Center,
        TextWrapped = true
    })
end

local function GetCategoryStates(
    scope: Fusion.Scope,
    outerScope: Fusion.Scope,
    collapsedStateScope: Fusion.Scope,
    instances: { Instance },
    omitRbxAttributes: boolean,
    showNonScriptableProperties: boolean
): { CategoryState }
    local categories: { CategoryState } = {}

    TableBulkInsert(categories, Categories.Properties(
        scope,
        outerScope,
        collapsedStateScope,
        instances,
        showNonScriptableProperties
    ))

    table.insert(categories, Categories.Tags(
        scope,
        outerScope,
        collapsedStateScope,
        instances
    ))

    table.insert(categories, Categories.Attributes(
        scope,
        outerScope,
        collapsedStateScope,
        instances,
        {
            OmitRbxAttributes = omitRbxAttributes
        }
    ))

    local visitedClasses: { [string]: boolean } = {}
    for _, instance in instances do
        local className = instance.ClassName
        if visitedClasses[className] then continue end
        visitedClasses[className] = true

        local extraCategories = ExtraCategories[className]
        if not extraCategories then continue end

        TableBulkInsert(
            categories,
            extraCategories(scope, outerScope, collapsedStateScope)
        )
    end

    return categories
end

return function(
    scope: Fusion.Scope,
    props: PropertiesMapsProps
)
    local selectedInstancesValue = props.SelectedInstancesValue
    local activeState: Fusion.UsedAs<boolean> =
        if props.Active == nil then true else props.Active
    local omitRbxAttributes = props.OmitRbxAttributes ~= false
    local outerScope = scope
    local collapsedStateScope = Fusion.innerScope(outerScope)
    local mapsScope = Fusion.innerScope(outerScope)
    local bookmarksOnlyState = GetBookmarksOnlyState(outerScope)
    local filterState = GetFilterState(outerScope)
    local categoryGenerations: {
        [CategoryGeneration]: boolean
    } = {}
    local categoryGenerationRevision = 0
    -- Generations are detached because their lifetime follows publication,
    -- rather than lexical nesting. Register their owner cleanup before the
    -- Computeds below so reverse-order cleanup destroys consumers first.
    table.insert(mapsScope, function()
        for generation in categoryGenerations do
            categoryGenerations[generation] = nil
            if generation.Alive then
                Fusion.doCleanup(generation.Scope)
            end
        end
    end)

    local computeCategoryGeneration = Computed(mapsScope, function(
        use
    ): CategoryGeneration
        local instances: { Instance }? = nil
        local showNonScriptableProperties = false

        if use<<boolean>>(activeState) then
            local selectedInstances =
                use<<{ Instance }>>(selectedInstancesValue)
            if #selectedInstances > 0 then
                instances = selectedInstances
                showNonScriptableProperties =
                    use<<boolean>>(props.ShowNonScriptableProperties)
            end
        end

        -- This scope is deliberately managed by categoryGenerations, not by
        -- Computed's callback scope. The previous generation must remain alive
        -- until its published VMS shape has retired.
        local generationScope = Fusion.deriveScope(mapsScope)
        categoryGenerationRevision += 1
        local generation: CategoryGeneration = {
            Scope = generationScope,
            States = {},
            Alive = true,
            Revision = categoryGenerationRevision
        }
        categoryGenerations[generation] = true
        table.insert(generationScope, function()
            generation.Alive = false
        end)

        if instances then
            generation.States = GetCategoryStates(
                generationScope,
                outerScope,
                collapsedStateScope,
                instances,
                omitRbxAttributes,
                showNonScriptableProperties
            )
        end

        return generation
    end)

    local computeRenderedMaps = Computed(mapsScope, function(
        use
    ): RenderedMaps
        local categoryGeneration =
            use<<CategoryGeneration>>(computeCategoryGeneration)
        local categoryStates = categoryGeneration.States
        local shapes =
            table.create(#categoryStates) :: { MapShape }
        local details =
            table.create(#categoryStates) :: { CategoryDetail }
        local mapCount = 0

        for _, categoryState in categoryStates do
            local category = use<<CategoryModel?>>(categoryState)
            if not category then continue end

            mapCount += 1
            local styledShape = table.clone(category.Shape)
            styledShape.HeaderColorTint = props.TintHeaders
            shapes[mapCount] = styledShape
            details[mapCount] = category.Detail
        end

        return {
            Shape = shapes,
            Detail = details
        }
    end)

    local mapsAlive = true
    local renderedMaps: Fusion.Value<RenderedMaps> = Value(
        mapsScope,
        Peek<<RenderedMaps>>(computeRenderedMaps)
    )
    local bookmarkButtonVisualState =
        GetBookmarkButtonVisualState(outerScope)
    local mapCommitQueued = false
    local mapCommitRevision = 0
    local committedMapRevision = 0
    local pendingBookmarkVisual: boolean? = nil

    local function retireSupersededCategoryGenerations(
        currentGeneration: CategoryGeneration
    )
        for generation, active in categoryGenerations do
            if not active then continue end

            -- A newer generation can be produced re-entrantly while the
            -- current snapshot is being published. It belongs to the next
            -- commit and must not be retired with older snapshots.
            if generation.Revision >= currentGeneration.Revision then
                continue
            end
            -- Keep queued generations discoverable by the owner cleanup until
            -- their deferred retirement has actually completed.
            categoryGenerations[generation] = false

            task.defer(function()
                if generation.Alive then
                    Fusion.doCleanup(generation.Scope)
                end
                categoryGenerations[generation] = nil
            end)
        end
    end

    local function commitRenderedMaps()
        local commitRevision = mapCommitRevision
        local nextCategoryGeneration =
            Peek<<CategoryGeneration>>(computeCategoryGeneration)
        renderedMaps:set(
            Peek<<RenderedMaps>>(computeRenderedMaps)
        )
        retireSupersededCategoryGenerations(
            nextCategoryGeneration
        )
        -- Preserve a revision queued re-entrantly by renderedMaps:set().
        committedMapRevision = commitRevision

        local bookmarkVisual = pendingBookmarkVisual
        pendingBookmarkVisual = nil
        if bookmarkVisual ~= nil then
            -- Start the icon crossfade only after the expensive map refresh
            -- has completed, so the refresh cannot consume its tween frames.
            task.defer(function()
                if not mapsAlive
                    or Peek<<boolean>>(bookmarksOnlyState)
                        ~= bookmarkVisual
                then
                    return
                end

                bookmarkButtonVisualState:set(bookmarkVisual)
            end)
        end
    end

    local function queueRenderedMapsCommit()
        mapCommitRevision += 1
        if mapCommitQueued then return end
        mapCommitQueued = true

        task.defer(function()
            mapCommitQueued = false
            if not mapsAlive
                or committedMapRevision == mapCommitRevision
            then
                return
            end

            commitRenderedMaps()
        end)
    end

    -- Hold the map list while the shared filter change propagates. This keeps
    -- the refresh atomic: every category switches modes before one map commit.
    Observer(mapsScope, bookmarksOnlyState):onChange(function()
        pendingBookmarkVisual =
            Peek<<boolean>>(bookmarksOnlyState)
        queueRenderedMapsCommit()
    end)

    Observer(mapsScope, computeRenderedMaps):onChange(function()
        queueRenderedMapsCommit()
    end)

    table.insert(mapsScope, function()
        mapsAlive = false
    end)

    local computeShape = Computed(mapsScope, function(
        use
    ): { MapShape }
        return use<<RenderedMaps>>(renderedMaps).Shape
    end)

    local loadDetail: VirtualMapScrollable.Detail = function(
        detailScope: Fusion.Scope,
        mapIdx: number,
        rowIdx: number
    )
        local rendered = Peek<<RenderedMaps>>(renderedMaps)
        local detail = assert(
            rendered.Detail[mapIdx],
            `Missing detail provider for map {mapIdx}.`
        )

        return detail(detailScope, rowIdx)
    end

    local computeEmptyMessage = Computed(mapsScope, function(
        use,
        scope: Fusion.Scope
    ): Fusion.Child?
        if not use<<boolean>>(activeState) then return nil end

        if #use<<{ Instance }>>(selectedInstancesValue) == 0 then
            return CreateEmptyMessage(scope, "No instances selected.")
        end

        local bookmarksOnly =
            use<<boolean>>(bookmarksOnlyState)
        local filter = use<<string?>>(filterState)
        local hasTextFilter =
            filter ~= nil and filter:match("%S") ~= nil
        if not bookmarksOnly and not hasTextFilter then
            return nil
        end

        local rendered = use<<RenderedMaps>>(renderedMaps)
        if #rendered.Shape > 0 then return nil end

        return CreateEmptyMessage(
            scope,
            if bookmarksOnly
            then "No bookmarked results found."
            else "No results found."
        )
    end)

    return VirtualMapScrollable(mapsScope, {
        Shape = computeShape,
        Detail = loadDetail,

        [Children] = {
            computeEmptyMessage
        }
    })
end
