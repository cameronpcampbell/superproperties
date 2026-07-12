--!strict

local Packages = script.Parent.Parent.Parent.packages

local Fusion = require(Packages.fusion)

local Mosaic = require(Packages.mosaic)
local Map = Mosaic.Map

local CategoryOrder = require(script.categoryOrder)
local GetCollapsedState = require(script.getCollapsedState)

local DefaultCategoryLayoutOrder = 999997

type CategoryProps = {
    Name: string,
    Items: {{
        Key: string,
        Value: any
    }},
    HideValues: boolean?,
    EmptyText: string?
}

type Item = { Key: string, Value: any }

local function SortItems(
    items: { Item }
): { Item }
    table.sort(items, function(a: Item, b: Item)
        return a.Key < b.Key
    end)

    return items
end

return function(
    scope: Fusion.Scope,
    outerScope: Fusion.Scope,
    props: CategoryProps
)
    local name = props.Name

    return Map(scope, {
        Header = name,
        Items = SortItems(props.Items),
        LayoutOrder =
            CategoryOrder[name] or
            DefaultCategoryLayoutOrder,
        -- We want this state to outlive the inner scope.
        Collapsed = GetCollapsedState(outerScope, name),
        HideValues = props.HideValues,
        EmptyText = props.EmptyText
    })
end
