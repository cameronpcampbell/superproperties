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

type PropertiesMapsProps = {
    SelectedInstancesValue: Fusion.Value<{ Instance }>,
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
    local omitRbxAttributes = props.OmitRbxAttributes ~= false
    local outerScope = scope
    local collapsedStateScope = Fusion.innerScope(outerScope)
    local mapsScope = Fusion.innerScope(outerScope)
    local bookmarksOnlyState = GetBookmarksOnlyState(outerScope)
    local filterState = GetFilterState(outerScope)

    local computeCategoryStates = Computed(mapsScope, function(
        use,
        scope: Fusion.Scope
    ): { CategoryState }
        local instances = use<<{ Instance }>>(selectedInstancesValue)
        local showNonScriptableProperties =
            use<<boolean>>(props.ShowNonScriptableProperties)
        if #instances == 0 then return {} end

        return GetCategoryStates(
            scope,
            outerScope,
            collapsedStateScope,
            instances,
            omitRbxAttributes,
            showNonScriptableProperties
        )
    end)

    local computeRenderedMaps = Computed(mapsScope, function(
        use
    ): RenderedMaps
        local categoryStates =
            use<<{ CategoryState }>>(computeCategoryStates)
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

    local mapRefreshPending = false
    local mapRefreshRevision = 0
    local mapsAlive = true
    local renderedMaps: Fusion.Value<RenderedMaps> = Value(
        mapsScope,
        Peek<<RenderedMaps>>(computeRenderedMaps)
    )
    local bookmarkButtonVisualState =
        GetBookmarkButtonVisualState(outerScope)

    -- Hold the map list while the shared filter change propagates. This keeps
    -- the refresh atomic: every category switches modes before one map commit.
    Observer(mapsScope, bookmarksOnlyState):onChange(function()
        mapRefreshRevision += 1
        local queuedRevision = mapRefreshRevision
        local bookmarksOnly =
            Peek<<boolean>>(bookmarksOnlyState)
        mapRefreshPending = true

        task.defer(function()
            if not mapsAlive
                or mapRefreshRevision ~= queuedRevision
                or Peek<<boolean>>(bookmarksOnlyState) ~= bookmarksOnly
            then
                return
            end

            mapRefreshPending = false
            renderedMaps:set(
                Peek<<RenderedMaps>>(computeRenderedMaps)
            )

            -- Start the icon crossfade only after the expensive map refresh
            -- has completed, so the refresh cannot consume its tween frames.
            task.defer(function()
                if not mapsAlive
                    or mapRefreshRevision ~= queuedRevision
                    or Peek<<boolean>>(bookmarksOnlyState) ~= bookmarksOnly
                then
                    return
                end

                bookmarkButtonVisualState:set(bookmarksOnly)
            end)
        end)
    end)

    Observer(mapsScope, computeRenderedMaps):onChange(function()
        if mapRefreshPending then return end

        renderedMaps:set(Peek<<RenderedMaps>>(computeRenderedMaps))
    end)

    table.insert(mapsScope, function()
        mapsAlive = false
        mapRefreshRevision += 1
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
