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
local LongPoll = require(script.Parent.Parent.longPoll)

local CustomPropertyPollInterval = 0.1

local function ConnectToPropertyChange(
    instance: Instance,
    propertyName: string,
    callback: () -> ()
): RBXScriptConnection?
    local connection: RBXScriptConnection? = nil
    local success = pcall(function()
        connection = instance:GetPropertyChangedSignal(propertyName):Connect(
            callback
        )
    end)

    if not success then return nil end
    return connection
end

local function ObservePropertyChanges(
    scope: Fusion.Scope,
    instance: Instance,
    snapshot: Snapshot,
    refreshProperty: (propertyName: string) -> ()
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
            if location.Plan.Poll then continue end

            local connection = ConnectToPropertyChange(
                instance,
                propertyName,
                function() refreshProperty(propertyName) end
            )

            if connection then table.insert(scope, connection) end
        end
    else
        table.insert(
            scope,
            instance.Changed:Connect(refreshProperty)
        )
    end

    if #polledPropertyNames > 0 then
        table.insert(scope, LongPoll(
            CustomPropertyPollInterval,
            function()
                for _, propertyName in polledPropertyNames do
                    refreshProperty(propertyName)
                end
            end
        ))
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
    local categoryStates =
        table.create(#snapshot.Categories) :: { CategoryState }

    for categoryIndex, categorySnapshot in snapshot.Categories do
        local items = categorySnapshot.Items
        local itemsState = Value(scope, items)

        categoryItems[categoryIndex] = items
        categoryItemStates[categoryIndex] = itemsState
        categoryStates[categoryIndex] = Category(
            scope,
            outerScope,
            collapsedStateScope,
            {
                Name = categorySnapshot.Name,
                Items = itemsState,
                Presorted = true,
                StableKeys = true
            }
        )
    end

    local function refreshProperty(propertyName: string)
        local location = snapshot.LocationsByName[propertyName]
        if not location then return end

        local readSuccess, value = GetProperties.ReadProperty(
            instance,
            location.Plan
        )
        if not readSuccess then return end

        local items = categoryItems[location.CategoryIndex]
        local item = items[location.ItemIndex]
        if item.Value == value then return end

        item.Value = value
        categoryItemStates[location.CategoryIndex]:set(items)
    end

    ObservePropertyChanges(
        scope,
        instance,
        snapshot,
        refreshProperty
    )

    return categoryStates
end
