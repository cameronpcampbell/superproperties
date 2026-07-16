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

local HoverRowZIndex = 100
local FocusRowZIndex = HoverRowZIndex + 1

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
    local isFocusElevationState: Fusion.Value<boolean>? = nil
    local rowZIndex: Fusion.UsedAs<number> = 1

    if hasInteractiveValue then
        isHoverState = Value(scope, false)
        isFocusState = Value(scope, false)
        isFocusElevationState = Value(scope, false)

        rowZIndex = Computed(scope, function(use: Fusion.Use): number
            if use<<boolean>>(
                isFocusElevationState :: Fusion.Value<boolean>
            ) then
                return FocusRowZIndex
            end

            return
                if use<<boolean>>(isHoverState :: Fusion.Value<boolean>) then
                    HoverRowZIndex
                else 1
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
            FocusElevationState = isFocusElevationState
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
        local childrenReveal =
            layout.ChildrenReveal :: Fusion.UsedAs<number>

        local subItemsVisible = Computed(scope, function(use): boolean
            return use<<number>>(childrenReveal) > 0
        end)

        -- Drive clipping from the reveal so moving child heights cannot toggle
        -- it mid-animation. The zero-height wrapper is hidden separately, and
        -- stable expanded bounds stay open for nested focus rings.
        local clipsDescendants = Computed(scope, function(use): boolean
            local reveal = use<<number>>(childrenReveal)
            return reveal > 0 and reveal < 1
        end)

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
            ClipsDescendants = clipsDescendants,
            Visible = subItemsVisible,
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
