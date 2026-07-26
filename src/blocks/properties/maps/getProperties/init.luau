--!strict
--!nolint LocalShadow

local ReflectionService = game:GetService("ReflectionService")
local Workspace = game:GetService("Workspace")

local Packages = script.Parent.Parent.Parent.Parent.packages

local Map = require(Packages.mosaic.components.map)

local ReflectionSecurity =
	require(script.Parent.Parent.Parent.Parent.reflectionSecurity)
local IsPropertyVisible = require(script.isPropertyVisible)
local Patches = require(script.patches)
local Types = require(script.types)

type Item = Map.Item

export type PropertyPlan = {
	Id: string,
	Owner: string,
	Name: string,
	ValueType: string?,
	Read: ((Instance) -> any)?,
	Write: ((Instance, any) -> ())?,
	Readable: boolean,
	Writable: boolean,
	ReadSecurity: string?,
	Poll: boolean,
	Visibility: Types.PropertyVisibility?,
}

type CategoryPlan = {
	Name: string,
	Properties: { PropertyPlan },
}

type ClassPlan = {
	Categories: { CategoryPlan },
}

export type CategorySnapshot = {
	Name: string,
	Items: { Item },
}

export type PropertyLocation = {
	Plan: PropertyPlan,
	CategoryIndex: number,
	ItemIndex: number,
}

export type Snapshot = {
	Categories: { CategorySnapshot },
	LocationsByName: { [string]: PropertyLocation },
}

local ClassPlansByName: { [string]: ClassPlan } = {}

local function MergeTables(target: { [any]: any }, source: { [any]: any })
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
	if not itemOwner then
		return item :: Types.PatchedReflectionPropertiesItem
	end

	local patchOwner = patchCategory[itemOwner]
	if not patchOwner then
		return item :: Types.PatchedReflectionPropertiesItem
	end

	local patchProperty = patchOwner[item.Name]
	if not patchProperty then
		return item :: Types.PatchedReflectionPropertiesItem
	end

	return MergeTables(table.clone(item) :: any, patchProperty)
end

local function ApplyPatches(item: Types.ReflectionPropertiesItem): Types.PatchedReflectionPropertiesItem
	local itemDisplay = item.Display
	if not itemDisplay then
		return item :: Types.PatchedReflectionPropertiesItem
	end

	local patchCategory = Patches[itemDisplay.Category]
	if not patchCategory then
		return item :: Types.PatchedReflectionPropertiesItem
	end

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
	if existingCategory then
		return existingCategory
	end

	local category = {
		Name = categoryName,
		Properties = {},
	}

	categoriesByName[categoryName] = category
	table.insert(categories, category)

	return category
end

local function BuildClassPlan(className: string): ClassPlan
	local categoriesByName: { [string]: CategoryPlan } = {}
	local classPlan: ClassPlan = {
		Categories = {},
	}

	local reflectedProperties =
		ReflectionService:GetPropertiesOfClass(
			className,
			{ Security = ReflectionSecurity.All }
		)
	local pluginSecurity = ReflectionSecurity.GetPlugin()

	for _, reflectedItem in reflectedProperties do
		local item = ApplyPatches(reflectedItem)
		local itemDisplay = item.Display

		if not itemDisplay then
			continue
		end
		if itemDisplay.DeprecationMessage then
			continue
		end
		if item.CustomVisibility == false then
			continue
		end

		local category = CreateOrGetCategoryPlan(classPlan.Categories, categoriesByName, itemDisplay.Category)

		local customReadWrite = item.CustomReadWrite
		local readPermits = item.Permits.Read
		local writePermits = item.Permits.Write
		local readable =
			customReadWrite ~= nil
			or (
				readPermits ~= nil
				and ReflectionSecurity.ContainsAll(
					pluginSecurity,
					readPermits
				)
			)
		local writable =
			customReadWrite ~= nil
			or (
				writePermits ~= nil
				and ReflectionSecurity.ContainsAll(
					pluginSecurity,
					writePermits
				)
			)
		local readSecurity =
			if not readable
				and not writable
				and readPermits ~= nil
			then ReflectionSecurity.DescribeMissing(readPermits)
			else nil
		local owner = item.Owner or className
		local propertyPlan: PropertyPlan = {
			Id = `{owner}\0{item.Name}`,
			Owner = owner,
			Name = item.Name,
			ValueType = item.Type.ScriptType,
			Read = if customReadWrite then customReadWrite.Read else nil,
			Write = if customReadWrite then customReadWrite.Write else nil,
			Readable = readable,
			Writable = writable,
			ReadSecurity = readSecurity,
			Poll = customReadWrite ~= nil and customReadWrite.Poll == true,
			Visibility = item.CustomVisibility,
		}

		table.insert(category.Properties, propertyPlan)
	end

	for _, category in classPlan.Categories do
		table.sort(category.Properties, function(leftProperty: PropertyPlan, rightProperty: PropertyPlan)
			return leftProperty.Name < rightProperty.Name
		end)
	end

	return classPlan
end

local function GetClassPlan(className: string): ClassPlan
	local classPlan = ClassPlansByName[className]
	if classPlan then
		return classPlan
	end

	local classPlan = BuildClassPlan(className)
	ClassPlansByName[className] = classPlan

	return classPlan
end

local function ReadProperty(instance: Instance, name: string): any
	return (instance :: any)[name]
end

local function ReadPlannedProperty(instance: Instance, propertyPlan: PropertyPlan): (boolean, any)
	if not propertyPlan.Readable then
		return false, nil
	end

	if propertyPlan.Read then
		return pcall(propertyPlan.Read, instance)
	end

	return pcall(ReadProperty, instance, propertyPlan.Name)
end

local function WriteProperty(instance: Instance, name: string, value: any)
	(instance :: any)[name] = value
end

local function IsPropertyWritable(instance: Instance, propertyPlan: PropertyPlan): boolean
	if not propertyPlan.Readable or not propertyPlan.Writable then
		return false
	end
	if propertyPlan.Name ~= "Parent" then
		return true
	end

	return instance.Parent ~= game and instance ~= Workspace.Terrain
end

local function WritePlannedProperty(instance: Instance, propertyPlan: PropertyPlan, value: any): (boolean, any)
	if not IsPropertyWritable(instance, propertyPlan) then
		return false, `Property '{propertyPlan.Name}' is read-only.`
	end

	if propertyPlan.Write then
		return pcall(propertyPlan.Write, instance, value)
	end

	return pcall(WriteProperty, instance, propertyPlan.Name, value)
end

local function GetProperties(
	instance: Instance,
	showNonScriptableProperties: boolean?
): Snapshot
	local categories: { CategorySnapshot } = {}
	local locationsByName: { [string]: PropertyLocation } = {}
	local classPlan = GetClassPlan(instance.ClassName)
	local showNonScriptableProperties =
		showNonScriptableProperties ~= false

	for _, categoryPlan in classPlan.Categories do
		local propertyPlans = categoryPlan.Properties
		local items = table.create(#propertyPlans) :: { Item }
		local categoryIndex = #categories + 1
		local itemCount = 0

		for _, propertyPlan in propertyPlans do
			local name = propertyPlan.Name
			local readSecurity = propertyPlan.ReadSecurity
			local warning = readSecurity ~= nil
			if warning and not showNonScriptableProperties then
				continue
			end

			local value: any
			local valueType: string
			local writable = false

			if warning then
				value = readSecurity :: string
				valueType = "string"
			else
				local readSuccess
				readSuccess, value =
					ReadPlannedProperty(instance, propertyPlan)
				if not readSuccess then
					continue
				end
				if not IsPropertyVisible(
					propertyPlan.Visibility,
					instance,
					value
				) then
					continue
				end

				valueType =
					propertyPlan.ValueType or typeof(value)
				writable =
					IsPropertyWritable(instance, propertyPlan)
			end

			itemCount += 1
			items[itemCount] = {
				Key = name,
				Warning = warning,
				Value = value,
				ValueType = valueType,
				ValueWritable = writable,
			}

			locationsByName[name] = {
				Plan = propertyPlan,
				CategoryIndex = categoryIndex,
				ItemIndex = itemCount,
			}
		end

		if itemCount == 0 then
			continue
		end

		categories[categoryIndex] = {
			Name = categoryPlan.Name,
			Items = items,
		}
	end

	return {
		Categories = categories,
		LocationsByName = locationsByName,
	}
end

return {
	Read = GetProperties,
	ReadProperty = ReadPlannedProperty,
	WriteProperty = WritePlannedProperty,
}
