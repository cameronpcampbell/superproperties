--!strict

local Packages = script.Parent.Parent.Parent.Parent.Parent.packages

local Fusion = require(Packages.fusion)
local Peek, Value = Fusion.peek, Fusion.Value

local Map = require(Packages.mosaic.components.map)
type Item = Map.Item
type TransformValue = Map.TransformValue
type ValueType = Map.ValueType

local Bookmarks = require(script.Parent.Parent.Parent.bookmarks)
local Category = require(script.Parent.Parent.category)
type RowDescriptor = Category.RowDescriptor
type CategoryState = Category.State

local GetProperties = require(script.Parent.Parent.getProperties)
type PropertyPlan = GetProperties.PropertyPlan
type PropertyMetadata = GetProperties.PropertyMetadata
local CommitProperty = require(script.commitProperty)
type CommitTarget = CommitProperty.Target
local LongPoll = require(script.Parent.Parent.longPoll)
type LongPollOptions = LongPoll.Options

type PropertyTargetPlan = {
    Instance: Instance,
    Plan: PropertyPlan,
    Writable: boolean,
    Warning: boolean
}

type PropertyTarget = {
    Instance: Instance,
    Plan: PropertyPlan,
    ValueState: Fusion.Value<any?>
}

type ObservePropertyChanges = (
    scope: Fusion.Scope,
    targets: { PropertyTarget }
) -> ()

type ChangedRouter = {
    TargetsByName: { [string]: { PropertyTarget } }
}

type PollRouter = {
    Targets: { PropertyTarget }
}

local GroupPropertyTargets = require(script.groupPropertyTargets)
type PropertyCandidate =
    GroupPropertyTargets.Candidate<PropertyTargetPlan>
type PropertyGroup =
    GroupPropertyTargets.Group<PropertyTargetPlan>
local NotScriptableValue = require(script.notScriptableValue)

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

local function CreatePropertyObserver(
    lifetimeScope: Fusion.Scope
): ObservePropertyChanges
    local changedRoutersByInstance: {
        [Instance]: ChangedRouter
    } = {}
    local pollRoutersByInstance: {
        [Instance]: PollRouter
    } = {}

    return function(
        scope: Fusion.Scope,
        targets: { PropertyTarget }
    )
        for _, target in targets do
            local plan = target.Plan
            if not plan.Readable then continue end

            if plan.Poll then
                local instance = target.Instance
                local pollRouter = pollRoutersByInstance[instance]
                if not pollRouter then
                    local newPollRouter: PollRouter = {
                        Targets = {}
                    }
                    pollRoutersByInstance[instance] = newPollRouter
                    pollRouter = newPollRouter

                    table.insert(
                        lifetimeScope,
                        LongPoll(PollOptions, function(): boolean
                            local foundChanges = false
                            for _, polledTarget in newPollRouter.Targets do
                                local changed =
                                    RefreshTarget(polledTarget)
                                if changed then
                                    foundChanges = true
                                end
                            end
                            return foundChanges
                        end)
                    )
                end

                table.insert(pollRouter.Targets, target)
                continue
            end

            local instance = target.Instance
            if instance:IsA("ValueBase") then
                local connection = ConnectToPropertyChange(
                    instance,
                    plan.Name,
                    function()
                        RefreshTarget(target)
                    end
                )
                if connection then table.insert(scope, connection) end
                continue
            end

            local router = changedRoutersByInstance[instance]
            if not router then
                local newRouter: ChangedRouter = {
                    TargetsByName = {}
                }
                changedRoutersByInstance[instance] = newRouter
                router = newRouter

                local usedRouter = newRouter
                table.insert(
                    lifetimeScope,
                    instance.Changed:Connect(function(propertyName: string)
                        local changedTargets =
                            usedRouter.TargetsByName[propertyName]
                        if not changedTargets then return end

                        for _, changedTarget in changedTargets do
                            RefreshTarget(changedTarget)
                        end
                    end)
                )
            end

            local targetsByName = router.TargetsByName
            local changedTargets = targetsByName[plan.Name]
            if not changedTargets then
                changedTargets = {}
                targetsByName[plan.Name] = changedTargets
            end
            table.insert(changedTargets, target)
        end
    end
end

local function GetBookmarkKey(group: PropertyGroup): string
    return Bookmarks.CreateKey(
        group.CategoryName,
        group.OwnerName,
        group.Name
    )
end

local function CreateUnavailableItem(group: PropertyGroup): Item
    return ({
        Key = group.Name,
        BookmarkKey = GetBookmarkKey(group),
        Warning = true,
        Value = "Unavailable",
        ValueType = "string",
        ValueWritable = false
    } :: any) :: Item
end

local function CreatePropertyItem(
    group: PropertyGroup,
    targets: { PropertyTarget },
    allWritable: boolean
): Item
    local comparisonValues =
        table.create(#targets) :: { Fusion.UsedAs<any?> }
    local commitTargets =
        table.create(#targets) :: { CommitTarget }

    for targetIdx, target in targets do
        comparisonValues[targetIdx] = target.ValueState
        commitTargets[targetIdx] = {
            Instance = target.Instance,
            Plan = target.Plan
        }
    end

    local function refreshTargets(): any?
        for _, target in targets do RefreshTarget(target) end
        return Peek<<any?>>(targets[1].ValueState)
    end

    local function tryTransformValue(
        transformValue: TransformValue
    ): (boolean, string?, any?)
        local success, err =
            CommitProperty(commitTargets, transformValue)
        local savedValue = refreshTargets()
        return success, err, if success then savedValue else nil
    end

    return ({
        Key = group.Name,
        BookmarkKey = GetBookmarkKey(group),
        Warning = group.Warning,
        Value = targets[1].ValueState,
        ComparisonValues = comparisonValues,
        ValueType =
            if group.Warning then NotScriptableValue else group.ValueType,
        ValueWritable = allWritable,
        TrySetValue = function(value: any): (boolean, string?, any?)
            return tryTransformValue(function(): any return value end)
        end,
        TryTransformValue = tryTransformValue
    } :: any) :: Item
end

local function HydratePropertyGroup(
    scope: Fusion.Scope,
    group: PropertyGroup,
    observePropertyChanges: ObservePropertyChanges
): Item
    local targets = table.create(#group.Targets) :: { PropertyTarget }
    local allWritable = true

    for _, targetPlan in group.Targets do
        local value: any

        if targetPlan.Warning then
            value = targetPlan.Plan.ReadSecurity or "Unknown capability"
        else
            local readSuccess
            readSuccess, value = GetProperties.ReadProperty(
                targetPlan.Instance,
                targetPlan.Plan
            )
            if not readSuccess then continue end
        end

        table.insert(targets, {
            Instance = targetPlan.Instance,
            Plan = targetPlan.Plan,
            ValueState = Value<<any?>>(scope, value)
        })
        if not targetPlan.Writable
            or not GetProperties.IsPropertyWritable(
                targetPlan.Instance,
                targetPlan.Plan
            )
        then
            allWritable = false
        end
    end

    if #targets == 0 then
        return CreateUnavailableItem(group)
    end

    observePropertyChanges(scope, targets)
    return CreatePropertyItem(group, targets, allWritable)
end

return function(
    scope: Fusion.Scope,
    outerScope: Fusion.Scope,
    collapsedStateScope: Fusion.Scope,
    instances: { Instance },
    showNonScriptableProperties: boolean
): { CategoryState }
    local propertyCandidates = {} :: { PropertyCandidate }
    local observePropertyChanges = CreatePropertyObserver(scope)

    for _, instance in instances do
        local metadata: { PropertyMetadata } = GetProperties.GetMetadata(
            instance,
            showNonScriptableProperties
        )

        for _, property in metadata do
            local plan = property.Plan
            local target: PropertyTargetPlan = {
                Instance = instance,
                Plan = plan,
                Writable = property.Writable,
                Warning = property.Warning
            }

            table.insert(propertyCandidates, {
                Id = plan.Id,
                OwnerName = plan.Owner,
                Name = plan.Name,
                CategoryName = property.CategoryName,
                ValueType = property.ValueType,
                Target = target,
                Writable = property.Writable,
                Warning = property.Warning
            })
        end
    end

    local groups, categoryNames =
        GroupPropertyTargets(propertyCandidates)
    local rowsByCategory: { [string]: { RowDescriptor } } = {}
    for _, categoryName in categoryNames do
        rowsByCategory[categoryName] = {}
    end
    for _, group in groups do
        local usedGroup = group
        local valueType: ValueType =
            if usedGroup.Warning
            then NotScriptableValue
            else usedGroup.ValueType

        table.insert(
            rowsByCategory[usedGroup.CategoryName],
            {
                Id = usedGroup.Id,
                Key = usedGroup.Name,
                BookmarkKey = GetBookmarkKey(usedGroup),
                ValueType = valueType,
                Hydrate = function(hydrationScope: Fusion.Scope): Item
                    return HydratePropertyGroup(
                        hydrationScope,
                        usedGroup,
                        observePropertyChanges
                    )
                end
            }
        )
    end

    local categoryStates = table.create(#categoryNames) :: { CategoryState }
    for categoryIdx, categoryName in categoryNames do
        local rows = rowsByCategory[categoryName]

        categoryStates[categoryIdx] = Category(
            scope,
            outerScope,
            collapsedStateScope,
            {
                Name = categoryName,
                Rows = rows,
                Bookmarkable = true,
                StableKeys = true
            }
        )
    end

    return categoryStates
end
