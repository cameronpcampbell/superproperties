--!strict
--!nolint LocalShadow

local Packages = script.Parent.Parent.Parent.Parent
local Typeforge = require(Packages.typeforge)

local Fusion = require(Packages.fusion)
local Computed, Peek, New, Children =
    Fusion.Computed, Fusion.peek, Fusion.New, Fusion.Children

local Utils = script.Parent.Parent.Parent.utils

local ThemeUtils = require(Utils.themeUtils)
local GetThemeForScope = ThemeUtils.GetThemeForScope

local Types = require(script.Parent.types)
local MapItemKey = require(script.key)
local MapItemValue = require(script.value)

type MapItemProps = Typeforge.Flatten<{
    Variant: ThemeUtils.BgVariantLayer,
    Layout: Types.ItemLayout,
    LayoutOrder: number,
    RowCount: Fusion.UsedAs<number>,
    RowMetadata: Fusion.UsedAs<Types.RowMetadata>,
    HideValue: boolean?
}>

local function MapItem(scope: Fusion.Scope, props: MapItemProps): Instance
    local theme = Peek<<ThemeUtils.Theme>>(GetThemeForScope(scope))
    local rowHeight = theme:GetHeight("Lg") - 2

    local layout = props.Layout
    local item = layout.Item
    local children = layout.Children
    local hasSubItems = #children > 0
    local redrawable = layout.CanBecomeMapBottom

    local rowIdx = Computed(scope, function(use): number
        local metadata = use<<Types.RowMetadata>>(props.RowMetadata)
        return metadata.RowIndices[layout] or 0
    end)

    local nestedChildren = table.create(#children + 1) :: { Fusion.Child }
    for childIdx, childLayout in children do
        nestedChildren[childIdx] = MapItem(scope, {
            Variant = props.Variant,
            Layout = childLayout,
            LayoutOrder = childIdx,
            RowCount = props.RowCount,
            RowMetadata = props.RowMetadata,
            HideValue = props.HideValue
        })
    end

    table.insert(nestedChildren, New(scope, "UIListLayout") {
        Padding = UDim.new(0, 1),
        FillDirection = Enum.FillDirection.Vertical,
        SortOrder = Enum.SortOrder.LayoutOrder
    })

    local itemContentChildren = {
        MapItemKey(scope, {
            Key = item.Key,
            Variant = props.Variant,
            RowCount = props.RowCount,
            RowIdx = rowIdx,
            HasSubItems = hasSubItems,
            Nestedness = layout.Depth,
            CollapsedState = layout.CollapsedState,
            Redrawable = redrawable
        })
    } :: { Fusion.Child }

    if not props.HideValue then
        table.insert(itemContentChildren, MapItemValue(scope, {
            Value = item.Value,
            Variant = props.Variant,
            RowCount = props.RowCount,
            RowIdx = rowIdx,
            Redrawable = redrawable
        }))
    end

    table.insert(itemContentChildren, New(scope, "UIListLayout") {
        Padding = UDim.new(0, 1),
        FillDirection = Enum.FillDirection.Horizontal,
        HorizontalFlex = Enum.UIFlexAlignment.Fill,
        SortOrder = Enum.SortOrder.LayoutOrder
    })

    local itemContent = New(scope, "Frame") {
        Size = UDim2.new(1, 0, 0, rowHeight),
        BackgroundTransparency = 1,
        Name = "ItemContent",

        [Children] = itemContentChildren
    }

    local subItemsClip: Instance? = nil
    if hasSubItems then
        subItemsClip = New(scope, "Frame") {
            Position = UDim2.fromOffset(0, rowHeight),
            Size = Computed(scope, function(use): UDim2
                return UDim2.new(
                    1,
                    0,
                    0,
                    use<<number>>(layout.AnimatedChildrenHeight)
                )
            end),
            BackgroundTransparency = 1,
            ClipsDescendants = true,
            Name = "SubItemsClip",

            [Children] = New(scope, "Frame") {
                Position = UDim2.fromOffset(0, 1),
                Size = Computed(scope, function(use): UDim2
                    return UDim2.new(
                        1,
                        0,
                        0,
                        use<<number>>(layout.ChildrenContentHeight)
                    )
                end),
                BackgroundTransparency = 1,
                Name = "SubItemsContent",

                [Children] = nestedChildren
            }
        }
    end

    local rootChildren = { itemContent } :: { Fusion.Child }
    if subItemsClip then table.insert(rootChildren, subItemsClip) end

    return New(scope, "Frame") {
        BackgroundTransparency = 1,
        Size = Computed(scope, function(use): UDim2
            return UDim2.new(
                1,
                0,
                0,
                use<<number>>(layout.AnimatedHeight)
            )
        end),
        LayoutOrder = props.LayoutOrder,

        Name = `MapItem [{item.Key}]`,

        [Children] = rootChildren
    }
end

return MapItem
