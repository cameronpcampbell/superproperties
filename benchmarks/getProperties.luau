--!strict
--!nolint LocalShadow

-- Measures the warm metadata-processing path with deterministic synthetic
-- reflection data. It does not include ReflectionService engine-call or UI
-- construction costs.

type Display = {
    Category: string,
    DeprecationMessage: string?
}

type ReflectionMemberFilter = {
    Security: any?,
    ExcludeInherited: boolean?,
    ExcludeDisplay: boolean?
}

type ReflectionItem = {
    Name: string,
    Owner: string,
    Serialized: boolean,
    Type: any,
    ContentType: any?,
    Display: Display?,
    Permits: {
        Read: any?,
        ReadParallel: any?,
        Write: any?,
        WriteParallel: any?
    },
    -- Added by SuperProperties patches, not ReflectionService.
    CustomReadWrite: {
        Read: (instance: { [string]: any }) -> any
    }?
}

type Category = {
    Properties: {{
        Key: string,
        Value: any,
        ValueType: string
    }}
}

type Properties = {
    [string]: Category
}

type Patch = { [string]: any }
type Patches = {
    [string]: {
        [string]: {
            [string]: Patch
        }
    }
}

type SyntheticInstance = {
    ClassName: string,
    [string]: any
}

type GetProperties = (SyntheticInstance) -> Properties

local CategoryCount = 12
local PropertyCount = 512
local InstancesPerClass = 32

local patches: Patches = {}
local reflections: { [string]: { ReflectionItem } } = {}

local function BuildReflection(className: string): { ReflectionItem }
    local reflection = table.create(PropertyCount) :: { ReflectionItem }

    for idx = 1, PropertyCount do
        local categoryName = `Category{(idx - 1) % CategoryCount + 1}`
        local propertyName = `Property{idx}`
        local owner = if idx % 2 == 0 then className else "BaseClass"

        reflection[idx] = {
            Name = propertyName,
            Owner = owner,
            Serialized = idx % 5 ~= 0,
            Type = {
                EngineType = if idx % 3 == 0 then "string" else "double",
                ScriptType = if idx % 3 == 0 then "string" else "number"
            },
            ContentType = nil,
            Display = {
                Category = categoryName,
                DeprecationMessage =
                    if idx % 97 == 0 then "Deprecated" else nil
            },
            Permits = {
                Read = if idx % 101 == 0 then "Restricted" else nil,
                ReadParallel = nil,
                Write = if idx % 103 == 0 then "Restricted" else nil,
                WriteParallel = nil
            }
        }

        if idx % 11 == 0 then
            local patchCategory = patches[categoryName]
            if not patchCategory then
                patchCategory = {}
                patches[categoryName] = patchCategory
            end

            local patchOwner = patchCategory[owner]
            if not patchOwner then
                patchOwner = {}
                patchCategory[owner] = patchOwner
            end

            patchOwner[propertyName] = {
                Display = {
                    Category = `Patched{(idx - 1) % 4 + 1}`
                }
            }
        end

        if idx % 127 == 0 or idx % 131 == 0 then
            local patchCategory = patches[categoryName]
            if not patchCategory then
                patchCategory = {}
                patches[categoryName] = patchCategory
            end

            local patchOwner = patchCategory[owner]
            if not patchOwner then
                patchOwner = {}
                patchCategory[owner] = patchOwner
            end

            local patch = (patchOwner[propertyName] or {}) :: Patch
            patchOwner[propertyName] = patch

            patch.CustomReadWrite = {
                Read =
                    if idx % 131 == 0 then
                        function(_instance)
                            error("synthetic unreadable property")
                        end
                    else
                        function(instance)
                            return instance[propertyName]
                        end
            }
        end
    end

    return reflection
end

local MockReflectionService = {}

function MockReflectionService:GetPropertiesOfClass(
    className: string,
    filter: ReflectionMemberFilter?
): { ReflectionItem }?
    local reflection = reflections[className]
    if not reflection then return nil end

    if not filter then return reflection end
    if not filter.ExcludeInherited and not filter.ExcludeDisplay then
        return reflection
    end

    local filtered = table.create(#reflection) :: { ReflectionItem }
    local filteredCount = 0

    for _, item in reflection do
        if filter.ExcludeInherited and item.Owner ~= className then
            continue
        end

        local filteredItem = item

        if filter.ExcludeDisplay and item.Display then
            filteredItem = table.clone(item)
            filteredItem.Display = nil
        end

        filteredCount += 1
        filtered[filteredCount] = filteredItem
    end

    return filtered
end

local function RegisterClass(className: string)
    if reflections[className] then return end
    reflections[className] = BuildReflection(className)
end

local function BuildInstances(
    classNames: { string }
): { SyntheticInstance }
    local instances = table.create(
        #classNames * InstancesPerClass
    ) :: { SyntheticInstance }

    for _, className in classNames do
        RegisterClass(className)

        for instanceIdx = 1, InstancesPerClass do
            local instance: SyntheticInstance = {
                ClassName = className
            }

            for propertyIdx = 1, PropertyCount do
                instance[`Property{propertyIdx}`] =
                    instanceIdx * PropertyCount + propertyIdx
            end

            instances[#instances + 1] = instance
        end
    end

    return instances
end

local function TableMergeFrozen(
    tableA: { [any]: any },
    tableB: { [any]: any }
): { [any]: any }
    for keyB, valueB in tableB do
        local valueA = tableA[keyB]

        if type(valueA) == "table" and type(valueB) == "table" then
            tableA[keyB] = TableMergeFrozen(table.clone(valueA), valueB)
        else
            tableA[keyB] = valueB
        end
    end

    return tableA
end

local function ApplyOwnerPatches(
    item: ReflectionItem,
    patchCategory: { [string]: any },
    itemOwner: string?
): ReflectionItem
    if not itemOwner then return item end

    local patchOwner = patchCategory[itemOwner]
    if not patchOwner then return item end

    local patchProperty = patchOwner[item.Name]
    if not patchProperty then return item end

    return TableMergeFrozen(
        table.clone(item) :: { [any]: any },
        patchProperty
    ) :: ReflectionItem
end

local function ApplyPatches(item: ReflectionItem): ReflectionItem
    local display = item.Display
    if not display then return item end

    local patchCategory = patches[display.Category]
    if not patchCategory then return item end

    local patchedItem = ApplyOwnerPatches(item, patchCategory, item.Owner)
    return ApplyOwnerPatches(patchedItem, patchCategory, "*")
end

local function CreateOrGetCategory(
    properties: Properties,
    categoryName: string
): Category
    local category = properties[categoryName]
    if category then return category end

    local createdCategory = {
        Properties = {}
    }

    properties[categoryName] = createdCategory
    return createdCategory
end

local function BaselineGetProperties(
    instance: SyntheticInstance
): Properties
    local reflection =
        MockReflectionService:GetPropertiesOfClass(instance.ClassName)
    if not reflection then error(`unknown class {instance.ClassName}`) end

    local properties: Properties = {}

    for _, reflectedItem in reflection do
        local item = ApplyPatches(reflectedItem)
        local display = item.Display

        if not display then continue end
        if display.DeprecationMessage then continue end

        local name = item.Name
        local ok, value = pcall(function()
            local customReadWrite = item.CustomReadWrite
            if customReadWrite then
                return customReadWrite.Read(instance)
            end

            return instance[name]
        end)

        if not ok then continue end

        table.insert(
            CreateOrGetCategory(properties, display.Category).Properties,
            {
                Key = name,
                Value = value,
                ValueType = item.Type.ScriptType or typeof(value)
            }
        )
    end

    return properties
end

type PropertyPlan = {
    Name: string,
    ValueType: string?,
    Read: ((instance: { [string]: any }) -> any)?
}

type CategoryPlan = {
    Name: string,
    Properties: { PropertyPlan }
}

type ClassPlan = { CategoryPlan }

local classPlansByName: { [string]: ClassPlan } = {}

local function CreateOrGetCategoryPlan(
    categories: ClassPlan,
    categoriesByName: { [string]: CategoryPlan },
    categoryName: string
): CategoryPlan
    local category = categoriesByName[categoryName]
    if category then return category end

    local category = {
        Name = categoryName,
        Properties = {}
    }

    categoriesByName[categoryName] = category
    table.insert(categories, category)

    return category
end

local function BuildClassPlan(className: string): ClassPlan
    local reflection = MockReflectionService:GetPropertiesOfClass(className)
    if not reflection then error(`unknown class {className}`) end

    local categoriesByName: { [string]: CategoryPlan } = {}
    local categories: ClassPlan = {}

    for _, reflectedItem in reflection do
        local item = ApplyPatches(reflectedItem)
        local display = item.Display

        if not display then continue end
        if display.DeprecationMessage then continue end

        local category = CreateOrGetCategoryPlan(
            categories,
            categoriesByName,
            display.Category
        )

        local customReadWrite = item.CustomReadWrite

        table.insert(category.Properties, {
            Name = item.Name,
            ValueType = item.Type.ScriptType,
            Read =
                if customReadWrite then customReadWrite.Read
                else nil
        })
    end

    for _, category in categories do
        table.sort(category.Properties, function(a: PropertyPlan, b: PropertyPlan)
            return a.Name < b.Name
        end)
    end

    return categories
end

local function GetClassPlan(className: string): ClassPlan
    local classPlan = classPlansByName[className]
    if classPlan then return classPlan end

    local builtClassPlan = BuildClassPlan(className)
    classPlansByName[className] = builtClassPlan
    return builtClassPlan
end

local function ReadProperty(
    instance: SyntheticInstance,
    name: string
): any
    return instance[name]
end

local function OptimizedGetProperties(
    instance: SyntheticInstance
): Properties
    local properties: Properties = {}

    for _, categoryPlan in GetClassPlan(instance.ClassName) do
        local propertyPlans = categoryPlan.Properties
        local items = table.create(#propertyPlans) :: {{
            Key: string,
            Value: any,
            ValueType: string
        }}
        local itemCount = 0

        for _, propertyPlan in propertyPlans do
            local name = propertyPlan.Name
            local read = propertyPlan.Read
            local ok, value

            if read then
                ok, value = pcall(read, instance)
            else
                ok, value = pcall(ReadProperty, instance, name)
            end

            if not ok then continue end

            itemCount += 1
            items[itemCount] = {
                Key = name,
                Value = value,
                ValueType = propertyPlan.ValueType or typeof(value)
            }
        end

        if itemCount > 0 then
            properties[categoryPlan.Name] = {
                Properties = items
            }
        end
    end

    return properties
end

local function Consume(properties: Properties): number
    local checksum = 0

    for categoryName, category in properties do
        checksum += #categoryName + #category.Properties

        for _, item in category.Properties do
            checksum += #item.Key + #item.ValueType + item.Value
        end
    end

    return checksum
end

local function Median(values: { number }): number
    table.sort(values)
    return values[math.ceil(#values / 2)]
end

local function Benchmark(
    name: string,
    getProperties: GetProperties,
    instances: { SyntheticInstance },
    iterations: number
): (number, number)
    local samples = table.create(9) :: { number }
    local checksum = 0

    for _, instance in instances do
        Consume(getProperties(instance))
    end

    for sampleIdx = 1, 9 do
        local startedAt = os.clock()
        local sampleChecksum = 0

        for iteration = 1, iterations do
            local instance = instances[(iteration - 1) % #instances + 1]
            sampleChecksum += Consume(getProperties(instance))
        end

        samples[sampleIdx] = os.clock() - startedAt
        checksum += sampleChecksum
    end

    local median = Median(samples)
    print(string.format(
        "%-22s %8.3f ms  %8.3f us/call  checksum=%d",
        name,
        median * 1_000,
        median * 1_000_000 / iterations,
        checksum
    ))

    return median, checksum
end

local sameClassInstances = BuildInstances({ "Class1" })
local mixedClassInstances =
    BuildInstances({ "Class2", "Class3", "Class4", "Class5" })

assert(
    MockReflectionService:GetPropertiesOfClass("UnknownClass") == nil,
    "invalid classes should return nil"
)

local ownProperties = MockReflectionService:GetPropertiesOfClass(
    "Class1",
    { ExcludeInherited = true }
)
assert(ownProperties, "registered class should return properties")
assert(
    #ownProperties == PropertyCount / 2,
    "ExcludeInherited should omit superclass properties"
)

local propertiesWithoutDisplay =
    MockReflectionService:GetPropertiesOfClass(
        "Class1",
        { ExcludeDisplay = true }
    )
assert(propertiesWithoutDisplay, "registered class should return properties")

for _, item in propertiesWithoutDisplay do
    assert(item.Display == nil, "ExcludeDisplay should omit display metadata")
end

local function ValidateEquivalent(instance: SyntheticInstance)
    local baseline = BaselineGetProperties(instance)
    local optimized = OptimizedGetProperties(instance)

    for categoryName, baselineCategory in baseline do
        local optimizedCategory = optimized[categoryName]
        assert(optimizedCategory, `missing category {categoryName}`)
        assert(
            #optimizedCategory.Properties == #baselineCategory.Properties,
            `property count changed in {categoryName}`
        )

        local baselineValues: { [string]: any } = {}
        local baselineValueTypes: { [string]: string } = {}
        for _, item in baselineCategory.Properties do
            baselineValues[item.Key] = item.Value
            baselineValueTypes[item.Key] = item.ValueType
        end

        local previousKey: string? = nil
        for _, item in optimizedCategory.Properties do
            if previousKey then
                assert(previousKey < item.Key, "optimized properties not sorted")
            end

            assert(
                baselineValues[item.Key] == item.Value,
                `property changed: {item.Key}`
            )
            assert(
                baselineValueTypes[item.Key] == item.ValueType,
                `property type changed: {item.Key}`
            )
            baselineValues[item.Key] = nil
            baselineValueTypes[item.Key] = nil
            previousKey = item.Key
        end

        assert(next(baselineValues) == nil, `properties missing in {categoryName}`)
        assert(
            next(baselineValueTypes) == nil,
            `property types missing in {categoryName}`
        )
    end

    for categoryName in optimized do
        assert(baseline[categoryName], `unexpected category {categoryName}`)
    end
end

ValidateEquivalent(sameClassInstances[1])

print(string.format(
    "getProperties synthetic benchmark (%d properties, %d categories)",
    PropertyCount,
    CategoryCount
))

local _, baselineSameClassChecksum = Benchmark(
    "baseline/same-class",
    BaselineGetProperties,
    sameClassInstances,
    400
)

local _, baselineMixedClassChecksum = Benchmark(
    "baseline/mixed-class",
    BaselineGetProperties,
    mixedClassInstances,
    400
)

local _, optimizedSameClassChecksum = Benchmark(
    "optimized/same-class",
    OptimizedGetProperties,
    sameClassInstances,
    400
)

local _, optimizedMixedClassChecksum = Benchmark(
    "optimized/mixed-class",
    OptimizedGetProperties,
    mixedClassInstances,
    400
)

assert(
    optimizedSameClassChecksum == baselineSameClassChecksum,
    "same-class result changed"
)

assert(
    optimizedMixedClassChecksum == baselineMixedClassChecksum,
    "mixed-class result changed"
)
