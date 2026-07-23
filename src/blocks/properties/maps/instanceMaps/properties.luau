--!strict

local Packages = script.Parent.Parent.Parent.Parent.Parent.packages

local Fusion = require(Packages.fusion)
local Value = Fusion.Value

local Map = require(Packages.mosaic.components.map)
type Item = Map.Item

local Category = require(script.Parent.Parent.category)
type CategoryState = Category.State

local GetProperties = require(script.Parent.Parent.getProperties)
type Snapshot = GetProperties.Snapshot
local CommitProperty = require(script.Parent.commitProperty)
local LongPoll = require(script.Parent.Parent.longPoll)
type LongPollOptions = LongPoll.Options

local PollOptions: LongPollOptions = {
	MinInterval = 0.1,
	MaxInterval = 0.5,
	BackoffFactor = 1.5,
}

local function ConnectToPropertyChange(
	instance: Instance,
	propertyName: string,
	callback: () -> ()
): RBXScriptConnection?
	local connection: RBXScriptConnection? = nil
	local success = pcall(function()
		connection = instance:GetPropertyChangedSignal(propertyName):Connect(callback)
	end)

	if not success then
		return nil
	end
	return connection
end

local function ObservePropertyChanges(
	scope: Fusion.Scope,
	instance: Instance,
	snapshot: Snapshot,
	refreshProperty: (propertyName: string) -> boolean
)
	local polledPropertyNames = {} :: { string }
	for propertyName, location in snapshot.LocationsByName do
		if location.Plan.Poll then
			table.insert(polledPropertyNames, propertyName)
		end
	end

	-- ValueBase.Changed sends the new value instead of a property name.
	if instance:IsA("ValueBase") then
		for propertyName, location in snapshot.LocationsByName do
			if location.Plan.Poll then
				continue
			end

			local connection = ConnectToPropertyChange(instance, propertyName, function()
				refreshProperty(propertyName)
			end)

			if connection then
				table.insert(scope, connection)
			end
		end
	else
		table.insert(
			scope,
			instance.Changed:Connect(function(propertyName: string)
				refreshProperty(propertyName)
			end)
		)
	end

	if #polledPropertyNames > 0 then
		table.insert(
			scope,
			LongPoll(PollOptions, function(): boolean
				local foundChanges = false

				for _, propertyName in polledPropertyNames do
					if refreshProperty(propertyName) then
						foundChanges = true
					end
				end

				return foundChanges
			end)
		)
	end
end

return function(
	scope: Fusion.Scope,
	outerScope: Fusion.Scope,
	collapsedStateScope: Fusion.Scope,
	instance: Instance
): { CategoryState }
	local snapshot = GetProperties.Read(instance)
	local categoryItems: { { Item } } = {}
	local categoryItemStates: { Fusion.Value<{ Item }> } = {}
	local categoryStates = table.create(#snapshot.Categories) :: { CategoryState }

	for categoryIndex, categorySnapshot in snapshot.Categories do
		local items = categorySnapshot.Items
		local itemsState = Value(scope, items)

		categoryItems[categoryIndex] = items
		categoryItemStates[categoryIndex] = itemsState
	end

	local function refreshProperty(propertyName: string): (boolean, any?)
		local location = snapshot.LocationsByName[propertyName]
		if not location then
			return false, nil
		end

		local readSuccess, value = GetProperties.ReadProperty(instance, location.Plan)
		if not readSuccess then
			return false, nil
		end

		local items = categoryItems[location.CategoryIndex]
		local item = items[location.ItemIndex]
		if item.Value == value then
			return false, value
		end

		item.Value = value
		categoryItemStates[location.CategoryIndex]:set(items)
		return true, value
	end

	for propertyName, location in snapshot.LocationsByName do
		local items = categoryItems[location.CategoryIndex]
		local item = items[location.ItemIndex]
		if not item.ValueWritable then
			continue
		end

		item.TrySetValue = function(value: any): (boolean, string?, any?)
			if item.Value == value then
				return true, nil, item.Value
			end

			local success, err = CommitProperty(instance, location.Plan, value)

			local _, savedValue = refreshProperty(propertyName)
			return success, err, if success then savedValue else nil
		end
	end

	for categoryIndex, categorySnapshot in snapshot.Categories do
		categoryStates[categoryIndex] = Category(scope, outerScope, collapsedStateScope, {
			Name = categorySnapshot.Name,
			Items = categoryItemStates[categoryIndex],
			Presorted = true,
			StableKeys = true,
		})
	end

	ObservePropertyChanges(scope, instance, snapshot, refreshProperty)

	return categoryStates
end
