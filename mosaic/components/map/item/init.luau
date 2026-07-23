--!strict
--!nolint LocalShadow

local Packages = script.Parent.Parent.Parent.Parent
local Typeforge = require(Packages.typeforge)

local Fusion = require(Packages.fusion)
local Computed, New, Children, Observer, Peek, Tween, Value =
    Fusion.Computed, Fusion.New, Fusion.Children, Fusion.Observer,
    Fusion.peek, Fusion.Tween, Fusion.Value

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
local HoverTweenInfo = require(script.hoverTweenInfo)
local ZIndices = require(script.Parent.zIndices)

local FocusRingActiveAlphaThreshold = .15

local function UseBooleanState(
    use: Fusion.Use,
    state: Fusion.Value<boolean>?
): boolean
    return state ~= nil and use<<boolean>>(state)
end

local function UseActiveFocusRing(
    use: Fusion.Use,
    state: Fusion.Value<number>?
): boolean
    return state ~= nil
        and use<<number>>(state) >= FocusRingActiveAlphaThreshold
end

type MapItemProps = Typeforge.Flatten<{
    Variant: ThemeUtils.BgVariantLayer,
    Layout: Types.ItemLayout,
    LayoutOrder: number,
    RowCount: Fusion.UsedAs<number>,
    RowMetadata: Fusion.UsedAs<Types.RowMetadata>
}>

local function CreateRightChildren(
    scope: Fusion.Scope,
    name: string,
    children: { Fusion.Child }?,
    hoverState: Fusion.Value<boolean>
): Instance?
    if not children or next(children) == nil then return nil end

    local transparency = Tween<<number>>(
        scope,
        Computed(scope, function(use: Fusion.Use): number
            return if use<<boolean>>(hoverState) then 0 else 1
        end),
        HoverTweenInfo
    )

    return New(scope, "CanvasGroup") {
        Size = UDim2.fromScale(0, 1),
        AutomaticSize = Enum.AutomaticSize.X,
        BackgroundTransparency = 1,
        GroupTransparency = transparency,
        Interactable = hoverState,
        LayoutOrder = 2,

        Name = name,

        [Children] = {
            children,

            New(scope, "UIListLayout") {
                Padding = UDim.new(0, 6),
                FillDirection = Enum.FillDirection.Horizontal,
                VerticalAlignment = Enum.VerticalAlignment.Center,
                SortOrder = Enum.SortOrder.LayoutOrder
            }
        }
    }
end

local function CreateMapItem(
    scope: Fusion.Scope,
    props: MapItemProps,
    bottomRowZIndexOut: Fusion.Value<number>?
): Instance
    local layout = props.Layout
    local item = layout.Item
    local key = item.Key
    local hasValue = item.Value ~= nil
    local children = layout.Children
    local hasSubItems = #children > 0
    local redrawable = layout.CanBecomeMapBottom
    local hasInteractiveKey = layout.KeyWritable
    local hasInteractiveValue = hasValue and layout.ValueWritable
    local hasKeyChildren =
        item.KeyChildren ~= nil and next(item.KeyChildren) ~= nil
    local hasValueChildren =
        hasValue
        and item.ValueChildren ~= nil
        and next(item.ValueChildren) ~= nil

    local keyHoverState: Fusion.Value<boolean>? =
        if hasInteractiveKey or hasKeyChildren
        then Value(scope, false)
        else nil
    local valueHoverState: Fusion.Value<boolean>? =
        if hasInteractiveValue or hasValueChildren
        then Value(scope, false)
        else nil
    local keyFocusState: Fusion.Value<boolean>? = nil
    local keyFocusElevationState: Fusion.Value<boolean>? = nil
    local keyFocusRingAlphaState: Fusion.Value<number>? = nil
    local valueFocusState: Fusion.Value<boolean>? = nil
    local valueFocusElevationState: Fusion.Value<boolean>? = nil
    local valueFocusRingAlphaState: Fusion.Value<number>? = nil
    local rowZIndex: Fusion.UsedAs<number> = ZIndices.Default

    if hasInteractiveKey then
        keyFocusState = layout.KeyFocusState
        keyFocusElevationState = layout.KeyFocusElevationState
        keyFocusRingAlphaState = Value(scope, 0)
    end

    if hasInteractiveValue then
        valueFocusState = layout.ValueFocusState
        valueFocusElevationState = layout.ValueFocusElevationState
        valueFocusRingAlphaState = Value(scope, 0)
    end

    if hasInteractiveKey or hasInteractiveValue then
        rowZIndex = Computed(scope, function(use: Fusion.Use): number
            if UseActiveFocusRing(use, keyFocusRingAlphaState)
                or UseActiveFocusRing(use, valueFocusRingAlphaState)
            then
                return ZIndices.Focus
            end
            if UseBooleanState(use, keyFocusElevationState)
                or UseBooleanState(use, valueFocusElevationState)
            then
                return ZIndices.DisappearingFocus
            end
            if UseBooleanState(use, keyHoverState)
                or UseBooleanState(use, valueHoverState)
            then
                return ZIndices.Hover
            end
            return ZIndices.Default
        end)
    end

    local rowIdx = Computed(scope, function(use: Fusion.Use): number
        local metadata = use<<Types.RowMetadata>>(props.RowMetadata)
        return metadata.RowIndices[layout] or 0
    end)

    local bottomRowZIndex = bottomRowZIndexOut
    local nestedChildren: Fusion.Child = {}

    if hasSubItems then
        local nestedBottomRowZIndex: Fusion.Value<number> =
            bottomRowZIndex or Value<<number>>(scope, ZIndices.Default)
        bottomRowZIndex = nestedBottomRowZIndex

        nestedChildren = Computed(scope, function(
            use: Fusion.Use,
            nestedScope: Fusion.Scope
        ): Fusion.Child
            if not use<<boolean>>(layout.ChildrenMounted) then return {} end

            local mountedChildren =
                table.create(#children + 1) :: { Fusion.Child }

            for childIdx, childLayout in children do
                mountedChildren[childIdx] = CreateMapItem(nestedScope, {
                    Variant = props.Variant,
                    Layout = childLayout,
                    LayoutOrder = childIdx,
                    RowCount = props.RowCount,
                    RowMetadata = props.RowMetadata
                }, if childIdx == #children then nestedBottomRowZIndex else nil)
            end

            table.insert(mountedChildren, New(nestedScope, "UIListLayout") {
                Padding = UDim.new(0, 1),
                FillDirection = Enum.FillDirection.Vertical,
                SortOrder = Enum.SortOrder.LayoutOrder
            })

            return (mountedChildren :: unknown) :: Fusion.Child
        end)
    end

    if bottomRowZIndex then
        local usedBottomRowZIndex = bottomRowZIndex
        local computeOwnBottomRowZIndex = Computed(
            scope,
            function(use: Fusion.Use): number?
                if hasSubItems
                    and use<<boolean>>(layout.ChildrenMounted)
                then
                    return nil
                end

                return use<<number>>(rowZIndex)
            end
        )

        local function publishOwnBottomRowZIndex()
            local ownBottomRowZIndex =
                Peek<<number?>>(computeOwnBottomRowZIndex)
            if ownBottomRowZIndex == nil then return end
            if Peek<<number>>(usedBottomRowZIndex) == ownBottomRowZIndex then
                return
            end

            usedBottomRowZIndex:set(ownBottomRowZIndex)
        end

        Observer(scope, computeOwnBottomRowZIndex)
            :onBind(publishOwnBottomRowZIndex)
    end

    local containerZIndex: Fusion.UsedAs<number> = rowZIndex
    if hasSubItems then
        local usedBottomRowZIndex =
            bottomRowZIndex :: Fusion.Value<number>
        containerZIndex = Computed(scope, function(use: Fusion.Use): number
            return math.max(
                use<<number>>(rowZIndex),
                use<<number>>(usedBottomRowZIndex)
            )
        end)
    end

    local theme = GetThemeForScope(scope)
    local rowHeight = ComputeAdd(scope, theme:GetHeight(scope, "Lg"), - 2)

    local itemContentChildren = {} :: { Fusion.Child }

    table.insert(itemContentChildren, MapItemKey(scope, {
        Key = key,
        Writable = layout.KeyWritable,
        DisplayAsWritable = layout.DisplayAsWritable,
        TrySetKey = layout.TrySetKey,
        Variant = props.Variant,
        RowCount = props.RowCount,
        RowIdx = rowIdx,
        Side = if hasValue then "Left" else "Both",
        HasSubItems = hasSubItems,
        Nestedness = layout.Depth,
        CollapsedState = layout.CollapsedState,
        Redrawable = redrawable,
        HoverState = keyHoverState,
        FocusState = keyFocusState,
        FocusElevationState = keyFocusElevationState,
        FocusRingAlphaState = keyFocusRingAlphaState,
        RightChildren = if keyHoverState then
            CreateRightChildren(
                scope,
                "KeyChildren",
                item.KeyChildren,
                keyHoverState
            )
            else nil
    }))

    if hasValue then
        table.insert(itemContentChildren, MapItemValue(scope, {
            Value = layout.ResolvedValue,
            Writable = layout.ValueWritable,
            DisplayAsWritable = layout.DisplayAsWritable,
            TrySetValue = layout.TrySetValue,
            Variant = props.Variant,
            RowCount = props.RowCount,
            RowIdx = rowIdx,
            Redrawable = redrawable,
            HoverState = valueHoverState,
            FocusState = valueFocusState,
            FocusElevationState = valueFocusElevationState,
            FocusRingAlphaState = valueFocusRingAlphaState,
            RightChildren = if hasValueChildren then
                CreateRightChildren(
                    scope,
                    "ValueChildren",
                    item.ValueChildren,
                    valueHoverState :: Fusion.Value<boolean>
                )
                else nil
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

    local instance = New(scope, "Frame") {
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
        ZIndex = containerZIndex,

        Name = `MapItem [{key}]`,

        [Children] = rootChildren
    }

    return instance
end

local function MapItem(scope: Fusion.Scope, props: MapItemProps): Instance
    return CreateMapItem(scope, props, nil)
end

return MapItem
