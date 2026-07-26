--!strict

local Packages = script.Parent.Parent.Parent.Parent.Parent.packages

local Fusion = require(Packages.fusion)
local Peek, Value = Fusion.peek, Fusion.Value

local Map = require(Packages.mosaic.components.map)
type Item = Map.Item
type TransformValue = Map.TransformValue

local Category = require(script.Parent.Parent.category)
type CategoryState = Category.State

local GetProperties = require(script.Parent.Parent.getProperties)
type PropertyPlan = GetProperties.PropertyPlan
type Snapshot = GetProperties.Snapshot
local CommitProperty = require(script.commitProperty)
type CommitTarget = CommitProperty.Target
local LongPoll = require(script.Parent.Parent.longPoll)
type LongPollOptions = LongPoll.Options

type PropertyTarget = {
    Instance: Instance,
    Plan: PropertyPlan,
    ValueState: Fusion.Value<any?>
}

local GroupPropertyTargets = require(script.groupPropertyTargets)
type PropertyCandidate =
    GroupPropertyTargets.Candidate<PropertyTarget>
type PropertyGroup =
    GroupPropertyTargets.Group<PropertyTarget>

local PollOptions: LongPollOptions = {
    MinInterval = 0.1,
    MaxInterval = 0.5,
    BackoffFactor = 1.5
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

    if not success then return nil end
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
        if not location.Plan.Readable then continue end
        if location.Plan.Poll then
            table.insert(polledPropertyNames, propertyName)
        end
    end

    if instance:IsA("ValueBase") then
        for propertyName, location in snapshot.LocationsByName do
            if not location.Plan.Readable then continue end
            if location.Plan.Poll then continue end

            local connection = ConnectToPropertyChange(instance, propertyName, function()
                refreshProperty(propertyName)
            end)
            if connection then table.insert(scope, connection) end
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

local function RefreshTarget(target: PropertyTarget): (boolean, any?)
    if not target.Plan.Readable then return false, nil end

    local readSuccess, value =
        GetProperties.ReadProperty(target.Instance, target.Plan)
    if not readSuccess then return false, nil end
    if Peek<<any?>>(target.ValueState) == value then
        return false, value
    end

    target.ValueState:set(value)
    return true, value
end

local function CreatePropertyItem(group: PropertyGroup): Item
    local comparisonValues =
        table.create(#group.Targets) :: { Fusion.UsedAs<any?> }
    local commitTargets =
        table.create(#group.Targets) :: { CommitTarget }

    for targetIdx, target in group.Targets do
        comparisonValues[targetIdx] = target.ValueState
        commitTargets[targetIdx] = {
            Instance = target.Instance,
            Plan = target.Plan
        }
    end

    local function refreshTargets(): any?
        for _, target in group.Targets do RefreshTarget(target) end
        return Peek<<any?>>(group.Targets[1].ValueState)
    end

    local function tryTransformValue(
        transformValue: TransformValue
    ): (boolean, string?, any?)
        local success, err =
            CommitProperty(commitTargets, transformValue)
        local savedValue = refreshTargets()
        return success, err, if success then savedValue else nil
    end

    return {
        Key = group.Name,
        Warning = group.Warning,
        Value = group.Targets[1].ValueState,
        ComparisonValues = comparisonValues,
        ValueType = group.ValueType,
        ValueWritable = group.AllWritable,
        TrySetValue = function(value: any): (boolean, string?, any?)
            return tryTransformValue(function(): any return value end)
        end,
        TryTransformValue = tryTransformValue
    }
end

return function(
    scope: Fusion.Scope,
    outerScope: Fusion.Scope,
    collapsedStateScope: Fusion.Scope,
    instances: { Instance }
): { CategoryState }
    local snapshotsByInstance: { [Instance]: Snapshot } = {}
    local targetsByInstance: {
        [Instance]: { [string]: PropertyTarget }
    } = {}
    local propertyCandidates = {} :: { PropertyCandidate }

    for _, instance in instances do
        local snapshot = GetProperties.Read(instance)
        local instanceTargets: { [string]: PropertyTarget } = {}
        snapshotsByInstance[instance] = snapshot
        targetsByInstance[instance] = instanceTargets

        for propertyName, location in snapshot.LocationsByName do
            local categorySnapshot =
                snapshot.Categories[location.CategoryIndex]
            local item = categorySnapshot.Items[location.ItemIndex]
            local plan = location.Plan

            local target: PropertyTarget = {
                Instance = instance,
                Plan = plan,
                ValueState = Value<<any?>>(scope, item.Value)
            }
            instanceTargets[propertyName] = target

            local itemValueType = item.ValueType
            table.insert(propertyCandidates, {
                Id = plan.Id,
                Name = plan.Name,
                CategoryName = categorySnapshot.Name,
                ValueType =
                    if type(itemValueType) == "string"
                    then itemValueType
                    else typeof(item.Value),
                Target = target,
                Writable = item.ValueWritable == true,
                Warning = item.Warning == true
            })
        end
    end

    local groups, categoryNames =
        GroupPropertyTargets(propertyCandidates)
    local itemsByCategory: { [string]: { Item } } = {}
    for _, categoryName in categoryNames do
        itemsByCategory[categoryName] = {}
    end
    for _, group in groups do
        table.insert(
            itemsByCategory[group.CategoryName],
            CreatePropertyItem(group)
        )
    end

    local categoryStates = table.create(#categoryNames) :: { CategoryState }
    for categoryIdx, categoryName in categoryNames do
        local items = itemsByCategory[categoryName]
        table.sort(items, function(leftItem: Item, rightItem: Item): boolean
            return leftItem.Key < rightItem.Key
        end)

        categoryStates[categoryIdx] = Category(
            scope,
            outerScope,
            collapsedStateScope,
            {
                Name = categoryName,
                Items = items,
                Presorted = true,
                StableKeys = true
            }
        )
    end

    for _, instance in instances do
        local instanceTargets = targetsByInstance[instance]
        local function refreshProperty(propertyName: string): boolean
            local target = instanceTargets[propertyName]
            if not target then return false end

            local changed = RefreshTarget(target)
            return changed
        end

        ObservePropertyChanges(
            scope,
            instance,
            snapshotsByInstance[instance],
            refreshProperty
        )
    end

    return categoryStates
end
