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
    SelectedInstanceValue: Fusion.Value<Instance?>,
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
    })
end

local function GetCategoryStates(
    scope: Fusion.Scope,
    outerScope: Fusion.Scope,
    collapsedStateScope: Fusion.Scope,
    instance: Instance,
    omitRbxAttributes: boolean
): { CategoryState }
    local categories: { CategoryState } = {}

    TableBulkInsert(categories, InstanceMaps.Properties(
        scope,
        outerScope,
        collapsedStateScope,
        instance
    ))

    table.insert(categories, InstanceMaps.Tags(
        scope,
        outerScope,
        collapsedStateScope,
        instance
    ))

    table.insert(categories, InstanceMaps.Attributes(
        scope,
        outerScope,
        collapsedStateScope,
        instance,
        {
            OmitRbxAttributes = omitRbxAttributes
        }
    ))

    local extraCategories = ExtraCategories[instance.ClassName]
    if not extraCategories then return categories end

    TableBulkInsert(
        categories,
        extraCategories(scope, outerScope, collapsedStateScope)
    )

    return categories
end

return function(
    scope: Fusion.Scope,
    props: PropertiesMapsProps
)
    local selectedInstanceValue = props.SelectedInstanceValue
    local omitRbxAttributes = props.OmitRbxAttributes ~= false
    local outerScope = scope
    local collapsedStateScope = Fusion.innerScope(outerScope)
    local mapsScope = Fusion.innerScope(outerScope)
    local filterState = GetFilterState(outerScope)

    local computeCategoryStates = Computed(mapsScope, function(
        use,
        scope: Fusion.Scope
    ): { CategoryState }
        local instance = use<<Instance?>>(selectedInstanceValue)
        if not instance then return {} end

        return GetCategoryStates(
            scope,
            outerScope,
            collapsedStateScope,
            instance,
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
        if not use<<Instance?>>(selectedInstanceValue) then
            return CreateEmptyMessage(scope, "No Instance selected.")
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
