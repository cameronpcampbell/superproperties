--!strict
--!nolint LocalShadow

local ReflectionService = game:GetService("ReflectionService")

local Packages = script.Parent.Parent.Parent.packages
local Typeforge = require(Packages.typeforge)

local Patches = require(script.patches)

type ReflectedProperties =
    index<Typeforge.Returns<typeof(ReflectionService.GetPropertiesOfClass)>, "1">
type ReflectionPropertiesData = index<ReflectedProperties, number>

type Category = {
    Properties: {{
        Key: string,
        Value: any
    }},
}

type Properties = {
    [string]: Category
}

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
    data: ReflectionPropertiesData,
    patchCategory: { [string]: any },
    dataOwner: string?
)
    if not dataOwner then return data end

    local patchOwner = patchCategory[dataOwner]
    if not patchOwner then return data end

    local patchProperty = patchOwner[data.Name]
    if not patchProperty then return data end

    return TableMergeFrozen(table.clone(data) :: any, patchProperty)
end

local function ApplyPatches(
    data: ReflectionPropertiesData
): ReflectionPropertiesData
    local dataDisplay = data.Display
    if not dataDisplay then return data end

    local patchCategory = Patches[dataDisplay.Category]
    if not patchCategory then return data end

    local data = ApplyOwnerPatches(data, patchCategory, data.Owner)
    local data = ApplyOwnerPatches(data, patchCategory, "*")

    return data
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
    local reflection = ReflectionService:GetPropertiesOfClass(instance.ClassName)

    local properties: Properties = {}

    for _, data in reflection do
        local data = ApplyPatches(data)

        local dataDisplay = data.Display
        if not dataDisplay then continue end
        if dataDisplay.DeprecationMessage then continue end

        local name = data.Name

        local ok, value = pcall(function()
            return (instance :: any)[name]
        end)

        if not ok then continue end

        table.insert(
            CreateOrGetCategory(properties, dataDisplay.Category).Properties,
            {
                Key = name,
                Value = value
            }
        )
    end

    return properties
end

return GetProperties
