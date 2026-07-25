--!strict

local Packages = script.Parent.Parent.Parent.packages

local Fusion = require(Packages.fusion)
local Children, Computed = Fusion.Children, Fusion.Computed

local Mosaic = require(Packages.mosaic)
local Text, VirtualMapScrollable =
    Mosaic.Text, Mosaic.VirtualMapScrollable

local Category = require(script.category)
type CategoryState = Category.State
type MapProps = Category.MapProps

type PropertiesMapsProps = {
    SelectedInstancesValue: Fusion.Value<{ Instance }>,
    OmitRbxAttributes: boolean?
}

local ExtraCategories = require(script.extraCategories)
local GetFilterState = require(script.Parent.getFilterState)
local InstanceMaps = require(script.instanceMaps)

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
    omitRbxAttributes: boolean
): { CategoryState }
    local categories: { CategoryState } = {}

    TableBulkInsert(categories, InstanceMaps.Properties(
        scope,
        outerScope,
        collapsedStateScope,
        instances
    ))

    table.insert(categories, InstanceMaps.Tags(
        scope,
        outerScope,
        collapsedStateScope,
        instances
    ))

    table.insert(categories, InstanceMaps.Attributes(
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
    local filterState = GetFilterState(outerScope)

    local computeCategoryStates = Computed(mapsScope, function(
        use,
        scope: Fusion.Scope
    ): { CategoryState }
        local instances = use<<{ Instance }>>(selectedInstancesValue)
        if #instances == 0 then return {} end

        return GetCategoryStates(
            scope,
            outerScope,
            collapsedStateScope,
            instances,
            omitRbxAttributes
        )
    end)

    local computeMapProps = Computed(mapsScope, function(use): { MapProps }
        local categoryStates =
            use<<{ CategoryState }>>(computeCategoryStates)
        local mapPropsList = table.create(#categoryStates) :: { MapProps }
        local mapCount = 0

        for _, categoryState in categoryStates do
            local mapProps = use<<MapProps?>>(categoryState)
            if not mapProps then continue end

            mapCount += 1
            mapPropsList[mapCount] = mapProps
        end

        return mapPropsList
    end)

    local computeEmptyMessage = Computed(mapsScope, function(
        use,
        scope: Fusion.Scope
    ): Fusion.Child?
        if #use<<{ Instance }>>(selectedInstancesValue) == 0 then
            return CreateEmptyMessage(scope, "No instances selected.")
        end

        local filter = use<<string?>>(filterState)
        local hasActiveFilter =
            filter ~= nil and filter:match("%S") ~= nil
        if not hasActiveFilter then return nil end

        local mapProps = use<<{ MapProps }>>(computeMapProps)
        if #mapProps > 0 then return nil end

        return CreateEmptyMessage(scope, "No results found.")
    end)

    return VirtualMapScrollable(mapsScope, {
        Maps = computeMapProps,

        [Children] = {
            computeEmptyMessage
        }
    })
end
