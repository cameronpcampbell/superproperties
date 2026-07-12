--!strict

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
        Value: any
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
                Name = if idx % 3 == 0 then "string" else "double"
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
    local instances = table.create(#classNames * InstancesPerClass)

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
                Value = value
            }
        )
    end

    return properties
end

local preparedPropertiesByClass: { [string]: { ReflectionItem } } = {}

local function GetPreparedProperties(
    className: string
): { ReflectionItem }
    local cachedProperties = preparedPropertiesByClass[className]
    if cachedProperties then return cachedProperties end

    local reflection = MockReflectionService:GetPropertiesOfClass(className)
    if not reflection then error(`unknown class {className}`) end

    local preparedProperties =
        table.create(#reflection) :: { ReflectionItem }
    local preparedPropertyCount = 0

    for _, reflectedItem in reflection do
        local item = ApplyPatches(reflectedItem)
        local display = item.Display

        if not display then continue end
        if display.DeprecationMessage then continue end

        preparedPropertyCount += 1
        preparedProperties[preparedPropertyCount] = item
    end

    preparedPropertiesByClass[className] = preparedProperties
    return preparedProperties
end

local function CachedGetProperties(
    instance: SyntheticInstance
): Properties
    local preparedProperties = GetPreparedProperties(instance.ClassName)
    local properties: Properties = {}

    for _, item in preparedProperties do
        local display = item.Display
        if not display then continue end

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
                Value = value
            }
        )
    end

    return properties
end

local function Consume(properties: Properties): number
    local checksum = 0

    for categoryName, category in properties do
        checksum += #categoryName + #category.Properties

        for _, item in category.Properties do
            checksum += #item.Key + item.Value
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

local _, cachedSameClassChecksum = Benchmark(
    "cached/same-class",
    CachedGetProperties,
    sameClassInstances,
    400
)

local _, cachedMixedClassChecksum = Benchmark(
    "cached/mixed-class",
    CachedGetProperties,
    mixedClassInstances,
    400
)

assert(
    cachedSameClassChecksum == baselineSameClassChecksum,
    "same-class result changed"
)

assert(
    cachedMixedClassChecksum == baselineMixedClassChecksum,
    "mixed-class result changed"
)
