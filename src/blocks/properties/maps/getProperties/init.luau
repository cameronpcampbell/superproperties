--!strict
--!nolint LocalShadow

local ReflectionService = game:GetService("ReflectionService")

local Patches = require(script.patches)
local Types = require(script.types)

type Category = {
    Properties: {{
        Key: string,
        Value: any
    }},
}

type Properties = {
    [string]: Category
}

type PreparedProperties = {
    Types.PatchedReflectionPropertiesItem
}

local PreparedPropertiesByClass: { [string]: PreparedProperties } = {}

local function TableMergeFrozen(
    tbleA: { [any]: any },
    tbleB:  { [any]: any }
)
    for keyB, valueB in tbleB do
        local valueA = tbleA[keyB]

		if type(valueA) == "table" and type(valueB) == "table" then
		    tbleA[keyB] = TableMergeFrozen(table.clone(valueA), valueB)

		else
		    tbleA[keyB] = valueB
		end
	end

	return tbleA
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

    return TableMergeFrozen(table.clone(item) :: any, patchProperty)
end

local function ApplyPatches(
    item: Types.ReflectionPropertiesItem
): Types.PatchedReflectionPropertiesItem
    local itemDisplay = item.Display
    if not itemDisplay then return item :: Types.PatchedReflectionPropertiesItem end

    local patchCategory = Patches[itemDisplay.Category]
    if not patchCategory then return item :: Types.PatchedReflectionPropertiesItem end

    local item = ApplyOwnerPatches(item, patchCategory, item.Owner)
    local item = ApplyOwnerPatches(item, patchCategory, "*")

    return item
end

local function GetPreparedProperties(className: string): PreparedProperties
    local cachedProperties = PreparedPropertiesByClass[className]
    if cachedProperties then return cachedProperties end

    local reflection = ReflectionService:GetPropertiesOfClass(className)
    local preparedProperties =
        table.create(#reflection) :: PreparedProperties
    local preparedPropertyCount = 0

    for _, reflectedItem in reflection do
        local item = ApplyPatches(reflectedItem)
        local itemDisplay = item.Display

        if not itemDisplay then continue end
        if itemDisplay.DeprecationMessage then continue end

        preparedPropertyCount += 1
        preparedProperties[preparedPropertyCount] = item
    end

    PreparedPropertiesByClass[className] = preparedProperties
    return preparedProperties
end

local function CreateOrGetCategory(
    properties: Properties,
    categoryName: string
): Category
    local category = properties[categoryName]
    if category then return category end

    local category = {
        Properties = {}
    }

    properties[categoryName] = category

    return category
end

local function GetProperties(instance: Instance): Properties
    local preparedProperties = GetPreparedProperties(instance.ClassName)
    local properties: Properties = {}

    for _, item in preparedProperties do
        local itemDisplay = item.Display
        if not itemDisplay then continue end
        local name = item.Name

        local ok, value = pcall(function()
            local customReadWrite = item.CustomReadWrite
            if customReadWrite then
                return customReadWrite.Read(instance)

            else
                return (instance :: any)[name]
            end
        end)

        if not ok then continue end

        table.insert(
            CreateOrGetCategory(properties, itemDisplay.Category).Properties,
            {
                Key = name,
                Value = value
            }
        )
    end

    return properties
end

return GetProperties
