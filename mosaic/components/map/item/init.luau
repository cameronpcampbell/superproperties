--!strict
--!nolint LocalShadow

local Packages = script.Parent.Parent.Parent.Parent
local Typeforge = require(Packages.typeforge)

local Fusion = require(Packages.fusion)
local Computed, New, Children, Value =
    Fusion.Computed, Fusion.New, Fusion.Children, Fusion.Value

local Utils = script.Parent.Parent.Parent.utils

local FusionUtils = require(Utils.fusionUtils)
local ComputeTransforms = FusionUtils.ComputeTransforms
local ComputeUDim2, ComputeUDim, ComputeUDim2FromOffset =
    ComputeTransforms.UDim2, ComputeTransforms.UDim,
    ComputeTransforms.UDim2FromOffset
local ComputeMath = FusionUtils.ComputeMath
local ComputeAdd = ComputeMath.Add

local ThemeUtils = require(Utils.themeUtils)
local GetThemeForScope = ThemeUtils.GetThemeForScope

local Types = require(script.Parent.types)
local MapItemKey = require(script.key)
local MapItemValue = require(script.value)

local ActiveRowZIndex = 100

type MapItemProps = Typeforge.Flatten<{
    Variant: ThemeUtils.BgVariantLayer,
    Layout: Types.ItemLayout,
    LayoutOrder: number,
    RowCount: Fusion.UsedAs<number>,
    RowMetadata: Fusion.UsedAs<Types.RowMetadata>,
    HideValue: boolean?
}>

local function MapItem(scope: Fusion.Scope, props: MapItemProps): Instance
    local layout = props.Layout
    local item = layout.Item
    local children = layout.Children
    local hasSubItems = #children > 0
    local redrawable = layout.CanBecomeMapBottom
    local hasInteractiveValue = layout.Writable and not props.HideValue

    local isHoverState: Fusion.Value<boolean>? = nil
    local isFocusState: Fusion.Value<boolean>? = nil
    local isBorderVisibleState: Fusion.Value<boolean>? = nil
    local rowZIndex: Fusion.UsedAs<number> = 1

    if hasInteractiveValue then
        isHoverState = Value(scope, false)
        isFocusState = Value(scope, false)
        isBorderVisibleState = Value(scope, false)

        rowZIndex = Computed(scope, function(use: Fusion.Use): number
            local shouldElevate =
                use<<boolean>>(isHoverState :: Fusion.Value<boolean>) or
                use<<boolean>>(isFocusState :: Fusion.Value<boolean>) or
                use<<boolean>>(isBorderVisibleState :: Fusion.Value<boolean>)

            return if shouldElevate then ActiveRowZIndex else 1
        end)
    end

    local rowIdx = Computed(scope, function(use: Fusion.Use): number
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

    local theme = GetThemeForScope(scope)
    local rowHeight = ComputeAdd(scope, theme:GetHeight(scope, "Lg"), - 2)

    table.insert(nestedChildren, New(scope, "UIListLayout") {
        Padding = UDim.new(0, 1),
        FillDirection = Enum.FillDirection.Vertical,
        SortOrder = Enum.SortOrder.LayoutOrder
    })

    local itemContentChildren = {
        MapItemKey(scope, {
            Key = item.Key,
            Writable = layout.Writable,
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
        local trySetValue =
            if layout.ValueAccessor then nil
            else (item :: Types.Item).TrySetValue

        table.insert(itemContentChildren, MapItemValue(scope, {
            Value = layout.ResolvedValue,
            Writable = layout.Writable,
            TrySetValue = trySetValue,
            Variant = props.Variant,
            RowCount = props.RowCount,
            RowIdx = rowIdx,
            Redrawable = redrawable,
            HoverState = isHoverState,
            FocusState = isFocusState,
            BorderVisibleState = isBorderVisibleState
        }))
    end

    table.insert(itemContentChildren, New(scope, "UIListLayout") {
        Padding = UDim.new(0, 1),
        FillDirection = Enum.FillDirection.Horizontal,
        HorizontalFlex = Enum.UIFlexAlignment.Fill,
        SortOrder = Enum.SortOrder.LayoutOrder
    })

    local itemContent = New(scope, "Frame") {
        Size = ComputeUDim2(scope, UDim.new(1, 0), ComputeUDim(scope, 0, rowHeight)),
        BackgroundTransparency = 1,
        Name = "ItemContent",

        [Children] = itemContentChildren
    }

    local subItemsClip: Instance? = nil
    if hasSubItems then
        subItemsClip = New(scope, "Frame") {
            Position = ComputeUDim2FromOffset(scope, 0, rowHeight),
            Size = Computed(scope, function(use: Fusion.Use): UDim2
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
                Size = Computed(scope, function(use: Fusion.Use): UDim2
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
        Size = Computed(scope, function(use: Fusion.Use): UDim2
            return UDim2.new(
                1,
                0,
                0,
                use<<number>>(layout.AnimatedHeight)
            )
        end),
        LayoutOrder = props.LayoutOrder,
        ZIndex = rowZIndex,

        Name = `MapItem [{item.Key}]`,

        [Children] = rootChildren
    }
end

return MapItem
