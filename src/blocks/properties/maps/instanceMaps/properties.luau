--!strict

local Packages = script.Parent.Parent.Parent.Parent.Parent.packages

local Fusion = require(Packages.fusion)
local Value = Fusion.Value

local Map = require(Packages.mosaic.components.map)
type Item = Map.Item

local Category = require(script.Parent.Parent.category)
type CategoryState = Category.State

type PropertiesMapProps = {
    Name: string,
    Items: { Item },
    ReadProperty: (propertyName: string) -> (boolean, any)
}

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

return function(
    scope: Fusion.Scope,
    outerScope: Fusion.Scope,
    collapsedStateScope: Fusion.Scope,
    instance: Instance,
    props: PropertiesMapProps
): CategoryState
    local propertyItems = table.clone(props.Items)
    local propertyItemsState = Value(scope, propertyItems)
    local propertyItemIndices: { [string]: number } = {}

    for itemIdx, item in propertyItems do
        propertyItemIndices[item.Key] = itemIdx
    end

    local function refreshProperty(propertyName: string)
        local itemIdx = propertyItemIndices[propertyName]
        if not itemIdx then return end

        local readSuccess, value = props.ReadProperty(propertyName)
        if not readSuccess then return end

        local nextPropertyItems = table.clone(propertyItems)
        local nextPropertyItem = table.clone(propertyItems[itemIdx])
        nextPropertyItem.Value = value
        nextPropertyItems[itemIdx] = nextPropertyItem

        propertyItems = nextPropertyItems
        propertyItemsState:set(nextPropertyItems)
    end

    for propertyName in propertyItemIndices do
        local connection = ConnectToPropertyChange(
            instance,
            propertyName,
            function() refreshProperty(propertyName) end
        )

        if connection then table.insert(scope, connection) end
    end

    return Category(scope, outerScope, collapsedStateScope, {
        Name = props.Name,
        Items = propertyItemsState,
        Presorted = true
    })
end
