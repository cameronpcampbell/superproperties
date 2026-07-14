--!strict
--!nolint LocalShadow

local ReflectionService = game:GetService("ReflectionService")

local Patches = require(script.patches)
local Types = require(script.types)

type PropertyItem = {
    Key: string,
    Value: any
}

type Category = {
    Properties: { PropertyItem },
}

type Properties = {
    [string]: Category
}

type PropertyPlan = {
    Name: string,
    Read: ((Instance) -> any)?
}

type CategoryPlan = {
    Name: string,
    Properties: { PropertyPlan }
}

type ClassPlan = { CategoryPlan }

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
    categories: ClassPlan,
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
    local categories: ClassPlan = {}

    local reflectedProperties = ReflectionService:GetPropertiesOfClass(className)

    for _, reflectedItem in reflectedProperties do
        local item = ApplyPatches(reflectedItem)
        local itemDisplay = item.Display

        if not itemDisplay then continue end
        if itemDisplay.DeprecationMessage then continue end

        local category = CreateOrGetCategoryPlan(
            categories,
            categoriesByName,
            itemDisplay.Category
        )

        local customReadWrite = item.CustomReadWrite

        table.insert(category.Properties, {
            Name = item.Name,
            Read =
                if customReadWrite then customReadWrite.Read
                else nil
        })
    end

    for _, category in categories do
        table.sort(category.Properties, function(
            leftProperty: PropertyPlan,
            rightProperty: PropertyPlan
        )
            return leftProperty.Name < rightProperty.Name
        end)
    end

    return categories
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

local function GetProperties(instance: Instance): Properties
    local properties: Properties = {}

    for _, categoryPlan in GetClassPlan(instance.ClassName) do
        local propertyPlans = categoryPlan.Properties
        local items = table.create(#propertyPlans) :: { PropertyItem }
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
        end

        if itemCount == 0 then continue end

        properties[categoryPlan.Name] = {
            Properties = items
        }
    end

    return properties
end

return GetProperties
