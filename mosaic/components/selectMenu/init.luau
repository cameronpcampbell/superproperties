--!strict
--!nolint LocalShadow

local Packages = script.Parent.Parent.Parent

local Fusion = require(Packages.fusion)
local New, Children, Value, Peek, Out, OnEvent, Computed, Observer, Tween =
    Fusion.New, Fusion.Children, Fusion.Value, Fusion.peek,
    Fusion.Out, Fusion.OnEvent, Fusion.Computed, Fusion.Observer, Fusion.Tween

local Utils = script.Parent.Parent.utils

local FusionUtils = require(Utils.fusionUtils)
local Component, CombineProps, CoerceToValue, ComposeTransparency =
    FusionUtils.Component, FusionUtils.CombineProps,
    FusionUtils.CoerceToValue, FusionUtils.ComposeTransparency
local ComputeTransforms = FusionUtils.ComputeTransforms
local ComputeUDim2, ComputeUDim =
    ComputeTransforms.UDim2, ComputeTransforms.UDim

local CreateItemFilter = require(Utils.filterItems)

local ThemeUtils = require(Utils.themeUtils)
local GetThemeForScope, GetNextVariant =
    ThemeUtils.GetThemeForScope, ThemeUtils.GetNextVariant

local TableUtils = require(Utils.tableUtils)
local TableExtract = TableUtils.Extract

local CoreComponents = script.Parent.Parent.coreComponents
local CoreInput = require(CoreComponents.input)

local Components = script.Parent.Parent.components
local Container = require(Components.container)
local Scrollable = require(Components.scrollable)
local Text = require(Components.text)

local SelectMenuItem = require(script.item)
local SelectMenuPlacement = require(script.placement)

type IndexedItem = {
    Idx: number,
    Text: string
}
type IndexedItemFilter =
    (query: string?, items: { IndexedItem }) -> { IndexedItem }

type SelectMenuProps = {
	Variant: ThemeUtils.BgVariantLayer?,
	Width: Fusion.UsedAs<UDim>?,
	MaxHeight: Fusion.UsedAs<number>?,
	Position: Fusion.UsedAs<UDim2>?,
	AnchorPoint: Fusion.UsedAs<Vector2>?,
	Items: Fusion.UsedAs<{ string }>,
	EnableSearch: Fusion.UsedAs<boolean>?,
	SearchState: Fusion.Value<string>?,
	SearchPlaceholderText: Fusion.UsedAs<string>?,
	SelectedIdx: Fusion.UsedAs<number?>?,
	DefaultIdx: Fusion.UsedAs<number>?,
	Visible: Fusion.UsedAs<boolean>?,
	Interactable: Fusion.UsedAs<boolean>?,
    EmptyText: Fusion.UsedAs<string>?,
    OutRenderVisible: Fusion.Value<boolean>?,
    OnSearchFocused: (() -> ())?,
    OnSearchFocusLost: ((boolean, InputObject?) -> ())?
}

local MenuPaddingHeight = 8
local SearchDividerHeight = 1

local VisibilityTweenInfo = TweenInfo.new(
    .23,
    Enum.EasingStyle.Quint,
    Enum.EasingDirection.InOut
)

local function GetGuiParent(instance: Instance): GuiBase2d?
    local parent = instance.Parent

    return
        if parent and parent:IsA("GuiBase2d") then parent :: GuiBase2d
        else nil
end

local function GetViewport(instance: Instance): LayerCollector?
    local ancestor = instance.Parent

    while ancestor do
        if ancestor:IsA("LayerCollector") then
            return ancestor :: LayerCollector
        end

        ancestor = ancestor.Parent
    end

    return nil
end


local function GetPositionOffsetScale(
    parent: GuiBase2d,
    viewport: LayerCollector
): number
    local scale = 1
    local ancestor: Instance? = parent

    while ancestor and ancestor ~= viewport do
        for _, child in ancestor:GetChildren() do
            if child:IsA("UIScale") then scale *= child.Scale end
        end

        ancestor = ancestor.Parent
    end

    return scale
end

return Component<<SelectMenuProps>>(function(scope, props)
    local props, variant = TableExtract(props, "Variant", "Tertiary")
    local props, width = TableExtract(props, "Width", UDim.new(1, 0))
    local props, maxHeight = TableExtract(props, "MaxHeight", math.huge)
    local props, preferredPosition =
        TableExtract(props, "Position", UDim2.fromScale(0, 0))
    local props, preferredAnchorPoint =
        TableExtract(props, "AnchorPoint", Vector2.zero)
    local props, items = TableExtract(props, "Items")
    local props, enableSearch = TableExtract(props, "EnableSearch", false)
    local props, providedSearchState = TableExtract(props, "SearchState")
    local props, searchPlaceholderText =
        TableExtract(props, "SearchPlaceholderText", "Search Items")
    local props, selectedIdx = TableExtract(props, "SelectedIdx")
    local props = TableExtract(props, "DefaultIdx")
    local props, visible = TableExtract(props, "Visible", true)
    local props, interactable = TableExtract(props, "Interactable", true)
    local props, emptyText =
        TableExtract(props, "EmptyText", "No results found.")
    local props, outRenderVisible =
        TableExtract(props, "OutRenderVisible")
    local props, onSearchFocused = TableExtract(props, "OnSearchFocused")
    local props, onSearchFocusLost = TableExtract(props, "OnSearchFocusLost")
    local props, backgroundTransparency =
        TableExtract(props, "BackgroundTransparency", 0)
    local props, strokeTransparency =
        TableExtract(props, "StrokeTransparency", 0)

    local selectedIdxValue = CoerceToValue<<number?>>(scope, selectedIdx)
    local searchState = providedSearchState or Value(scope, "")

    local effectivePreferredPosition = Computed(scope, function(use): UDim2
        return use<<UDim2>>(preferredPosition)
    end)

    local effectivePreferredAnchorPoint = Computed(scope, function(use): Vector2
        return use<<Vector2>>(preferredAnchorPoint)
    end)

    local renderedPosition =
        Value(scope, Peek<<UDim2>>(effectivePreferredPosition))
    local renderedAnchorPoint =
        Value(scope, Peek<<Vector2>>(effectivePreferredAnchorPoint))

    local isSearchEnabled = Computed(scope, function(use): boolean
        return use<<boolean>>(enableSearch)
    end)

    local effectiveSearchQuery = Computed(scope, function(use): string
        return
            if use<<boolean>>(isSearchEnabled) then
                use<<string>>(searchState)
            else ""
    end)

    Observer(scope, isSearchEnabled):onChange(function()
        if not Peek<<boolean>>(isSearchEnabled) then searchState:set("") end
    end)

    local indexedItems = Computed(scope, function(use): { IndexedItem }
        local usedItems = use<<{ string }>>(items)
        local result = table.create(#usedItems) :: { IndexedItem }

        for idx, text in usedItems do
            result[idx] = {
                Idx = idx,
                Text = text
            }
        end

        return result
    end)

    local itemFilter = Computed(scope, function(use): IndexedItemFilter
        return CreateItemFilter(
            use<<{ IndexedItem }>>(indexedItems),
            function(item: IndexedItem): string
                return item.Text
            end
        )
    end)

    local filteredItems = Computed(scope, function(use): { IndexedItem }
        local usedItems = use<<{ IndexedItem }>>(indexedItems)
        local usedItemFilter = use<<IndexedItemFilter>>(itemFilter)

        return usedItemFilter(use<<string>>(effectiveSearchQuery), usedItems)
    end)

    local hasNoFilteredItems = Computed(scope, function(use): boolean
        return #use<<{ IndexedItem }>>(filteredItems) == 0
    end)

    local shouldShowEmptyText = Computed(scope, function(use): boolean
        return
            use<<boolean>>(hasNoFilteredItems)
            and use<<string>>(emptyText) ~= ""
    end)

    local isVisible = Computed(scope, function(use): boolean
        return use<<boolean>>(visible)
    end)

    local visibilityTransparency = Tween<<number>>(
        scope,
        Computed(scope, function(use): number
            return if use<<boolean>>(isVisible) then 0 else 1
        end),
        VisibilityTweenInfo
    )

    local shouldRender = Computed(scope, function(use): boolean
        return
            use<<boolean>>(visible)
            or use<<number>>(visibilityTransparency) < .999
    end)

    Observer(scope, shouldRender):onBind(function()
        local isRendering = Peek<<boolean>>(shouldRender)

        if outRenderVisible then outRenderVisible:set(isRendering) end
        if not isRendering then searchState:set("") end
    end)

    local effectiveInteractable = Computed(scope, function(use): boolean
        return
            use<<boolean>>(visible)
            and use<<boolean>>(interactable)
    end)

    local effectiveSearchInteractable = Computed(scope, function(use): boolean
        return
            use<<boolean>>(isSearchEnabled)
            and use<<boolean>>(effectiveInteractable)
    end)

    local nextVariant = GetNextVariant(scope, variant)
    local scrollableVariant = Computed(scope, function(use)
        : ThemeUtils.BgVariantLayer
        local usedVariant = use<<ThemeUtils.BgVariantLayer>>(variant)

        return
            if usedVariant == "Quaternary" then usedVariant
            else use<<ThemeUtils.BgVariant>>(nextVariant)
                :: ThemeUtils.BgVariantLayer
    end)

    local theme = GetThemeForScope(scope)
    local strokeColor = theme:GetBg(scope, nextVariant)
    local textColor = theme:GetFg(scope, "Primary")
    local placeholderColor = theme:GetFg(scope, "Secondary")
    local largeHeight = theme:GetHeight(scope, "Lg")
    local font = theme:GetFont(scope, "Main", Enum.FontWeight.Medium)
    local fontSize = theme:GetFontSize(scope, "Main", "Title")

    local searchHeight = Computed(scope, function(use): number
        return math.max(use<<number>>(largeHeight) - 2, 0)
    end)

    local emptyRowHeight = Computed(scope, function(use): number
        return use<<number>>(largeHeight) - 4
    end)

    local searchChromeHeight = Computed(scope, function(use): number
        return
            if use<<boolean>>(isSearchEnabled) then
                use<<number>>(searchHeight) + SearchDividerHeight
            else 0
    end)

    local listContentSizeState =
        Value<<Vector2>>(scope, Vector2.new())
    local listViewportHeight = Computed(scope, function(use): number
        local availableHeight = math.max(
            use<<number>>(maxHeight) -
                use<<number>>(searchChromeHeight) -
                MenuPaddingHeight,
            0
        )

        return math.min(
            use<<Vector2>>(listContentSizeState).Y,
            availableHeight
        )
    end)

    local composedBackgroundTransparency = ComposeTransparency(
        scope,
        backgroundTransparency,
        visibilityTransparency
    )

    local composedStrokeTransparency = ComposeTransparency(
        scope,
        strokeTransparency,
        visibilityTransparency
    )

    local composedOpaqueTransparency = ComposeTransparency(
        scope,
        0,
        visibilityTransparency
    )

    local selectMenuRoot = Container(scope, CombineProps({
        Variant = variant,
        BackgroundTransparency = composedBackgroundTransparency,
        StrokeColor = strokeColor,
        StrokeTransparency = composedStrokeTransparency,
        Size = ComputeUDim2(scope, width, UDim.new(0, 0)),
        AutomaticSize = Enum.AutomaticSize.Y,
        Position = renderedPosition,
        AnchorPoint = renderedAnchorPoint,
        Visible = shouldRender,

        Name = "SelectMenu",

        RootChildren = {
            New(scope, "UIFlexItem") {},

            New(scope, "UISizeConstraint") {
                MaxSize = Computed(scope, function(use: Fusion.Use, scope)
                    return Vector2.new(math.huge, use<<number>>(maxHeight))
                end)
            },
        },

        [Children] = {
            CoreInput(scope, {
                Size = ComputeUDim2(
                    scope,
                    UDim.new(1, 0),
                    ComputeUDim(scope, 0, searchHeight)
                ),
                BackgroundTransparency = 1,
                Text = searchState,
                PlaceholderText = searchPlaceholderText,
                TextColor3 = textColor,
                PlaceholderColor3 = placeholderColor,
                TextTransparency = composedOpaqueTransparency,
                TextSize = fontSize,
                FontFace = font,
                ClearTextOnFocus = false,
                Interactable = effectiveSearchInteractable,
                TextEditable = effectiveSearchInteractable,
                TextXAlignment = Enum.TextXAlignment.Left,
                Visible = isSearchEnabled,

                [Out "Text"] = searchState,
                [OnEvent "Focused"] = onSearchFocused,
                [OnEvent "FocusLost"] = onSearchFocusLost,

                [Children] = New(scope, "UIPadding") {
                    PaddingLeft = UDim.new(0, 6),
                    PaddingRight = UDim.new(0, 6)
                },

                Name = "Search"
            }),

            New(scope, "Frame") {
                BackgroundColor3 = strokeColor,
                BackgroundTransparency = composedStrokeTransparency,
                BorderSizePixel = 0,
                Size = UDim2.new(1, 0, 0, SearchDividerHeight),
                Visible = isSearchEnabled,

                Name = "Divider"
            },

            New(scope, "Frame") {
                Size = UDim2.new(1, 0, 0, 0),
                BackgroundTransparency = 1,
                AutomaticSize = Enum.AutomaticSize.Y,

                [Children] = {
                    Scrollable(scope, {
                        Variant = scrollableVariant,
                        Size = ComputeUDim2(
                            scope,
                            UDim.new(1, 0),
                            ComputeUDim(scope, 0, listViewportHeight)
                        ),
                        AutomaticSize = Enum.AutomaticSize.None,
                        AutomaticCanvasSize = Enum.AutomaticSize.Y,
                        ClipsDescendants = true,
                        PaddingRight = UDim.new(0, 3),
                        Transparency = visibilityTransparency,

                        [Children] = {
                            Text(scope, {
                                Text = emptyText,
                                Variant = "Secondary",
                                Size = ComputeUDim2(
                                    scope,
                                    UDim.new(1, 0),
                                    ComputeUDim(scope, 0, emptyRowHeight)
                                ),
                                AutomaticSize = Enum.AutomaticSize.None,
                                TextTransparency = composedOpaqueTransparency,
                                TextXAlignment = Enum.TextXAlignment.Center,
                                TextYAlignment = Enum.TextYAlignment.Center,
                                Visible = shouldShowEmptyText,

                                Name = "SelectMenuEmptyText"
                            }),

                            Fusion.ForPairs(scope, filteredItems, function(
                                use,
                                scope,
                                key,
                                value
                            )
                                local usedItem = value

                                return usedItem.Idx, SelectMenuItem(scope, {
                                    Text = usedItem.Text,
                                    SelectedIdxValue = selectedIdxValue,
                                    Idx = usedItem.Idx,
                                    LayoutOrder = key,
                                    Transparency = visibilityTransparency,
                                    Interactable = effectiveInteractable
                                })
                            end),

                            New(scope, "UIListLayout") {
                                Padding = UDim.new(0, 1),
                                FillDirection = Enum.FillDirection.Vertical,
                                SortOrder = Enum.SortOrder.LayoutOrder,

                                [Out "AbsoluteContentSize"] =
                                    listContentSizeState
                            },
                        }
                    }),

                    New(scope, "UIPadding") {
                        PaddingLeft = UDim.new(0, 3),
                        PaddingRight = UDim.new(0, 3),
                        PaddingTop = UDim.new(0, 3),
                        PaddingBottom = UDim.new(0, 3),
                    },
                }
            },

            New(scope, "UIListLayout") {
                FillDirection = Enum.FillDirection.Vertical,
                SortOrder = Enum.SortOrder.LayoutOrder
            },

            New(scope, "UIPadding") {
                PaddingLeft = UDim.new(0, 1),
                PaddingRight = UDim.new(0, 1),
                PaddingTop = UDim.new(0, 1),
                PaddingBottom = UDim.new(0, 1),
            },
        }
    }, props)) :: GuiObject

    local scopeAlive = true
    local placementQueued = false
    local observedParent: GuiBase2d? = nil
    local observedViewport: LayerCollector? = nil
    local geometryConnections: { RBXScriptConnection } = {}
    local QueuePlacement: () -> ()

    local function DisconnectGeometryConnections()
        for _, connection in geometryConnections do
            connection:Disconnect()
        end

        table.clear(geometryConnections)
    end

    local function SetPlacement(position: UDim2, anchorPoint: Vector2)
        if Peek<<UDim2>>(renderedPosition) ~= position then
            renderedPosition:set(position)
        end

        if Peek<<Vector2>>(renderedAnchorPoint) ~= anchorPoint then
            renderedAnchorPoint:set(anchorPoint)
        end
    end

    local function RefreshGeometryConnections()
        local nextParent = GetGuiParent(selectMenuRoot)
        local nextViewport = GetViewport(selectMenuRoot)

        if nextParent == observedParent
            and nextViewport == observedViewport
        then
            return
        end

        DisconnectGeometryConnections()
        observedParent = nextParent
        observedViewport = nextViewport

        local function ObserveGeometry(gui: GuiBase2d)
            table.insert(
                geometryConnections,
                gui:GetPropertyChangedSignal("AbsolutePosition")
                    :Connect(QueuePlacement)
            )
            table.insert(
                geometryConnections,
                gui:GetPropertyChangedSignal("AbsoluteSize")
                    :Connect(QueuePlacement)
            )
        end

        if nextParent then ObserveGeometry(nextParent) end
        if nextViewport and nextViewport ~= nextParent then
            ObserveGeometry(nextViewport)
        end
    end

    local function UpdatePlacement()
        RefreshGeometryConnections()

        local usedPreferredPosition =
            Peek<<UDim2>>(effectivePreferredPosition)
        local usedPreferredAnchorPoint =
            Peek<<Vector2>>(effectivePreferredAnchorPoint)

        if not Peek<<boolean>>(shouldRender) then
            SetPlacement(
                usedPreferredPosition,
                usedPreferredAnchorPoint
            )
            return
        end

        local parent = observedParent
        local viewport = observedViewport
        local menuSize = selectMenuRoot.AbsoluteSize

        if not parent
            or not viewport
            or menuSize.X <= 0
            or menuSize.Y <= 0
            or viewport.AbsoluteSize.X <= 0
            or viewport.AbsoluteSize.Y <= 0
        then
            SetPlacement(
                usedPreferredPosition,
                usedPreferredAnchorPoint
            )
            return
        end

        local positionOffsetScale =
            GetPositionOffsetScale(parent, viewport)
        if positionOffsetScale <= 0 then
            SetPlacement(
                usedPreferredPosition,
                usedPreferredAnchorPoint
            )
            return
        end

        local placement = SelectMenuPlacement.Fit({
            PreferredPosition = usedPreferredPosition,
            PreferredAnchorPoint = usedPreferredAnchorPoint,
            ParentPosition = parent.AbsolutePosition,
            ParentSize = parent.AbsoluteSize,
            MenuSize = menuSize,
            ViewportPosition = viewport.AbsolutePosition,
            ViewportSize = viewport.AbsoluteSize,
            PositionOffsetScale = positionOffsetScale
        })

        SetPlacement(placement.Position, placement.AnchorPoint)
    end

    QueuePlacement = function()
        if placementQueued then return end
        placementQueued = true

        task.defer(function()
            placementQueued = false
            if not scopeAlive then return end

            UpdatePlacement()
        end)
    end

    table.insert(scope, function()
        scopeAlive = false
        DisconnectGeometryConnections()
    end)

    table.insert(
        scope,
        selectMenuRoot:GetPropertyChangedSignal("AbsoluteSize")
            :Connect(QueuePlacement)
    )
    table.insert(
        scope,
        selectMenuRoot.AncestryChanged:Connect(QueuePlacement)
    )

    Observer(scope, effectivePreferredPosition):onChange(QueuePlacement)
    Observer(scope, effectivePreferredAnchorPoint):onChange(QueuePlacement)
    Observer(scope, shouldRender):onBind(QueuePlacement)

    return selectMenuRoot
end)
