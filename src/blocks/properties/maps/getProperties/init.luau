--!strict
--!nolint LocalShadow

local ReflectionService = game:GetService("ReflectionService")

local Packages = script.Parent.Parent.Parent.Parent.packages

local Map = require(Packages.mosaic.components.map)

local Patches = require(script.patches)
local Types = require(script.types)

type Item = Map.Item

export type PropertyPlan = {
    Name: string,
    Read: ((Instance) -> any)?,
    Poll: boolean
}

type CategoryPlan = {
    Name: string,
    Properties: { PropertyPlan }
}

type ClassPlan = {
    Categories: { CategoryPlan }
}

export type CategorySnapshot = {
    Name: string,
    Items: { Item }
}

export type PropertyLocation = {
    Plan: PropertyPlan,
    CategoryIndex: number,
    ItemIndex: number
}

export type Snapshot = {
    Categories: { CategorySnapshot },
    LocationsByName: { [string]: PropertyLocation }
}

local ClassPlansByName: { [string]: ClassPlan } = {}

local function MergeTables(
    target: { [any]: any },
    source: { [any]: any }
)
    for sourceKey, sourceValue in source do
        local targetValue = target[sourceKey]

        if type(targetValue) ~= "table" or type(sourceValue) ~= "table" then
            target[sourceKey] = sourceValue
            continue
        end

        target[sourceKey] = MergeTables(table.clone(targetValue), sourceValue)
    end

    return target
end

local function ApplyOwnerPatches(
    item: Types.ReflectionPropertiesItem,
    patchCategory: { [string]: any },
    itemOwner: string?
): Types.PatchedReflectionPropertiesItem
    if not itemOwner then return item :: Types.PatchedReflectionPropertiesItem end

    local patchOwner = patchCategory[itemOwner]
    if not patchOwner then return item :: Types.PatchedReflectionPropertiesItem end

    local patchProperty = patchOwner[item.Name]
    if not patchProperty then return item :: Types.PatchedReflectionPropertiesItem end

    return MergeTables(table.clone(item) :: any, patchProperty)
end

local function ApplyPatches(
    item: Types.ReflectionPropertiesItem
): Types.PatchedReflectionPropertiesItem
    local itemDisplay = item.Display
    if not itemDisplay then return item :: Types.PatchedReflectionPropertiesItem end

    local patchCategory = Patches[itemDisplay.Category]
    if not patchCategory then return item :: Types.PatchedReflectionPropertiesItem end

    local patchedItem = ApplyOwnerPatches(item, patchCategory, item.Owner)
    patchedItem = ApplyOwnerPatches(patchedItem, patchCategory, "*")

    return patchedItem
end

local function CreateOrGetCategoryPlan(
    categories: { CategoryPlan },
    categoriesByName: { [string]: CategoryPlan },
    categoryName: string
): CategoryPlan
    local existingCategory = categoriesByName[categoryName]
    if existingCategory then return existingCategory end

    local category = {
        Name = categoryName,
        Properties = {}
    }

    categoriesByName[categoryName] = category
    table.insert(categories, category)

    return category
end

local function BuildClassPlan(className: string): ClassPlan
    local categoriesByName: { [string]: CategoryPlan } = {}
    local classPlan: ClassPlan = {
        Categories = {}
    }

    local reflectedProperties = ReflectionService:GetPropertiesOfClass(className)

    for _, reflectedItem in reflectedProperties do
        local item = ApplyPatches(reflectedItem)
        local itemDisplay = item.Display

        if not itemDisplay then continue end
        if itemDisplay.DeprecationMessage then continue end

        local category = CreateOrGetCategoryPlan(
            classPlan.Categories,
            categoriesByName,
            itemDisplay.Category
        )

        local customReadWrite = item.CustomReadWrite
        local propertyPlan: PropertyPlan = {
            Name = item.Name,
            Read =
                if customReadWrite then customReadWrite.Read
                else nil,
            Poll = customReadWrite ~= nil and
                customReadWrite.Poll == true
        }

        table.insert(category.Properties, propertyPlan)
    end

    for _, category in classPlan.Categories do
        table.sort(category.Properties, function(
            leftProperty: PropertyPlan,
            rightProperty: PropertyPlan
        )
            return leftProperty.Name < rightProperty.Name
        end)
    end

    return classPlan
end

local function GetClassPlan(className: string): ClassPlan
    local classPlan = ClassPlansByName[className]
    if classPlan then return classPlan end

    local classPlan = BuildClassPlan(className)
    ClassPlansByName[className] = classPlan

    return classPlan
end

local function ReadProperty(instance: Instance, name: string): any
    return (instance :: any)[name]
end

local function ReadPlannedProperty(
    instance: Instance,
    propertyPlan: PropertyPlan
): (boolean, any)
    if propertyPlan.Read then
        return pcall(propertyPlan.Read, instance)
    end

    return pcall(ReadProperty, instance, propertyPlan.Name)
end

local function GetProperties(instance: Instance): Snapshot
    local categories: { CategorySnapshot } = {}
    local locationsByName: { [string]: PropertyLocation } = {}
    local classPlan = GetClassPlan(instance.ClassName)

    for _, categoryPlan in classPlan.Categories do
        local propertyPlans = categoryPlan.Properties
        local items = table.create(#propertyPlans) :: { Item }
        local categoryIndex = #categories + 1
        local itemCount = 0

        for _, propertyPlan in propertyPlans do
            local name = propertyPlan.Name
            local readSuccess, value =
                ReadPlannedProperty(instance, propertyPlan)
            if not readSuccess then continue end

            itemCount += 1
            items[itemCount] = {
                Key = name,
                Value = value
            }

            locationsByName[name] = {
                Plan = propertyPlan,
                CategoryIndex = categoryIndex,
                ItemIndex = itemCount
            }
        end

        if itemCount == 0 then continue end

        categories[categoryIndex] = {
            Name = categoryPlan.Name,
            Items = items
        }
    end

    return {
        Categories = categories,
        LocationsByName = locationsByName
    }
end

return {
    Read = GetProperties,
    ReadProperty = ReadPlannedProperty
}
