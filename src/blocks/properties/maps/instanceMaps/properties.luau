--!strict

local Packages = script.Parent.Parent.Parent.Parent.Parent.packages

local Fusion = require(Packages.fusion)
local Peek, Value = Fusion.peek, Fusion.Value

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
	local propertyValueStates: { [string]: Fusion.Value<any?> } = {}
	local categoryStates = table.create(#snapshot.Categories) :: { CategoryState }

	-- The item collection is fixed for the lifetime of this instance. Publish
	-- property changes through leaf states so existing rows keep interaction
	-- state and open overlays.
	for _, categorySnapshot in snapshot.Categories do
		for _, item in categorySnapshot.Items do
			local valueState = Value<<any?>>(scope, item.Value)

			item.Value = valueState
			propertyValueStates[item.Key] = valueState
		end
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

		local valueState = propertyValueStates[propertyName]
		if not valueState then
			return false, nil
		end
		if Peek<<any?>>(valueState) == value then
			return false, value
		end

		valueState:set(value)
		return true, value
	end

	for propertyName, location in snapshot.LocationsByName do
		local categorySnapshot =
			snapshot.Categories[location.CategoryIndex]
		local item = categorySnapshot.Items[location.ItemIndex]
		if not item.ValueWritable then
			continue
		end
		local valueState = propertyValueStates[propertyName]

		item.TrySetValue = function(value: any): (boolean, string?, any?)
			local currentValue = Peek<<any?>>(valueState)
			if currentValue == value then
				return true, nil, currentValue
			end

			local success, err = CommitProperty(instance, location.Plan, value)

			local _, savedValue = refreshProperty(propertyName)
			return success, err, if success then savedValue else nil
		end
	end

	for categoryIndex, categorySnapshot in snapshot.Categories do
		categoryStates[categoryIndex] = Category(scope, outerScope, collapsedStateScope, {
			Name = categorySnapshot.Name,
			Items = categorySnapshot.Items,
			Presorted = true,
			StableKeys = true,
		})
	end

	ObservePropertyChanges(scope, instance, snapshot, refreshProperty)

	return categoryStates
end
