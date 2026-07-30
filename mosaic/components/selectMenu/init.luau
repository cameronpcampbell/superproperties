--!strict
--!nolint LocalShadow

local Packages = script.Parent.Parent.Parent
local Supercorner = require(Packages.supercorner)

local Fusion = require(Packages.fusion)
local New, Children, Value, Peek, Out, OnEvent, Computed, Observer, Tween =
    Fusion.New, Fusion.Children, Fusion.Value, Fusion.peek,
    Fusion.Out, Fusion.OnEvent, Fusion.Computed, Fusion.Observer, Fusion.Tween

local Utils = script.Parent.Parent.utils

local FusionUtils = require(Utils.fusionUtils)
local Component, CombineProps, CoerceToValue, ComposeTransparency, Oktween =
    FusionUtils.Component, FusionUtils.CombineProps,
    FusionUtils.CoerceToValue, FusionUtils.ComposeTransparency,
    FusionUtils.Oktween
local ComputeTransforms = FusionUtils.ComputeTransforms
local ComputeUDim2, ComputeUDim =
    ComputeTransforms.UDim2, ComputeTransforms.UDim

local CreateItemFilter = require(Utils.filterItems)

local ThemeUtils = require(Utils.themeUtils)
local GetThemeForScope, GetNextVariant, CalcColorModifier =
    ThemeUtils.GetThemeForScope, ThemeUtils.GetNextVariant,
    ThemeUtils.CalcColorModifier

local TableUtils = require(Utils.tableUtils)
local TableExtract = TableUtils.Extract

local CoreComponents = script.Parent.Parent.coreComponents
local CoreFrame = require(CoreComponents.frame)
local CoreInput = require(CoreComponents.input)
local Placement = require(CoreComponents.placement)
local TransparencyGated = require(CoreComponents.transparencyGated)

local Components = script.Parent.Parent.components
local Container = require(Components.container)
local FocusRing = require(Components.focusRing)
local Scrollable = require(Components.scrollable)
local Text = require(Components.text)

local SelectMenuItem = require(script.item)

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
	SortOrder: Enum.SortOrder?,
	SelectedIdx: Fusion.UsedAs<number?>?,
	DefaultIdx: Fusion.UsedAs<number>?,
	Visible: Fusion.UsedAs<boolean>?,
	Interactable: Fusion.UsedAs<boolean>?,
    Transparency: Fusion.UsedAs<number>?,
    EmptyText: Fusion.UsedAs<string>?,
    OutRenderVisible: Fusion.Value<boolean>?,
    OnSearchFocused: (() -> ())?,
    OnSearchFocusLost: ((boolean, InputObject?) -> ())?
}

local MenuPaddingHeight = 8
local SearchDividerHeight = 1

local SearchHoverTweenInfo = TweenInfo.new(
    .18,
    Enum.EasingStyle.Exponential,
    Enum.EasingDirection.InOut
)

local FocusTransitionTweenInfo = TweenInfo.new(
    .23,
    Enum.EasingStyle.Quint,
    Enum.EasingDirection.InOut
)

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
    local props, sortOrder =
        TableExtract(props, "SortOrder", Enum.SortOrder.LayoutOrder)
    local props, selectedIdx = TableExtract(props, "SelectedIdx")
    local props = TableExtract(props, "DefaultIdx")
    local props, visible = TableExtract(props, "Visible", true)
    local props, interactable = TableExtract(props, "Interactable", true)
    local props, transparency =
        TableExtract(props, "Transparency", 0)
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
    local searchState = (providedSearchState or Value(scope, "")) :: Fusion.Value<string>

    local isSearchEnabled = Computed(scope, function(use): boolean
        return use<<boolean>>(enableSearch)
    end)

    local effectiveSearchQuery = Computed(scope, function(use): string
        return
            if use<<boolean>>(isSearchEnabled) then
                use<<string>>(searchState)
            else ""
    end)

    local effectiveSortOrder = Computed(scope, function(use): Enum.SortOrder
        local query = use<<string>>(effectiveSearchQuery)
        local hasSearchFilter = query:find("%S") ~= nil

        return
            if hasSearchFilter then Enum.SortOrder.LayoutOrder
            else sortOrder
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

    local transitionTransparency = Value(
        scope,
        if Peek<<boolean>>(isVisible) then 0 else 1
    )
    local contentTransparency = ComposeTransparency(
        scope,
        transparency,
        transitionTransparency
    )
    local composedStrokeTransparency = ComposeTransparency(
        scope,
        strokeTransparency,
        contentTransparency
    )

    local renderVisible = Value(
        scope,
        Peek<<boolean>>(isVisible)
    )
    Observer(scope, renderVisible):onBind(function()
        local isRendering = Peek<<boolean>>(renderVisible)

        if outRenderVisible then
            local output = outRenderVisible :: Fusion.Value<boolean>
            if Peek<<boolean>>(output) ~= isRendering then
                output:set(isRendering)
            end
        end
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

    local searchHoverState = Value(scope, false)
    local searchFocusState = Value(scope, false)
    local visualSearchHoverState = Computed(scope, function(use): boolean
        return
            use<<boolean>>(effectiveSearchInteractable)
            and use<<boolean>>(searchHoverState)
    end)
    local visualSearchFocusState = Computed(scope, function(use): boolean
        return
            use<<boolean>>(effectiveSearchInteractable)
            and use<<boolean>>(searchFocusState)
    end)

    Observer(scope, effectiveSearchInteractable):onChange(function()
        if Peek<<boolean>>(effectiveSearchInteractable) then return end

        searchHoverState:set(false)
        searchFocusState:set(false)
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
    local searchStrokeColorModifier:
        Fusion.UsedAs<ThemeUtils.ThemeColorModifier?> =
        CalcColorModifier(
            scope,
            visualSearchHoverState,
            visualSearchFocusState,
            "Stroke"
        )
    local searchHoverStrokeColor = theme:GetBg(
        scope,
        nextVariant,
        searchStrokeColorModifier
    )
    local searchAccentColor = theme:GetAccent(
        scope,
        "Primary",
        searchStrokeColorModifier
    )
    local textColor = theme:GetFg(scope, "Primary")
    local placeholderColor = theme:GetFg(scope, "Secondary")
    local largeHeight = theme:GetHeight(scope, "Lg")
    local searchCornerRadius =
        Peek<<number>>(theme:GetCornerRadius(scope, "Md")) - 1
    local font = theme:GetFont(scope, "Main", Enum.FontWeight.Medium)
    local fontSize = theme:GetFontSize(scope, "Main", "Title")

    local animatedSearchStrokeColor = Oktween(
        scope,
        Computed(scope, function(use): Color3
            return
                if use<<boolean>>(visualSearchFocusState) then
                    use<<Color3>>(searchAccentColor)
                else use<<Color3>>(searchHoverStrokeColor)
        end),
        SearchHoverTweenInfo
    )

    local animatedSearchStrokeTransparency = Tween<<number>>(
        scope,
        Computed(scope, function(use): number
            local shouldShow =
                use<<boolean>>(visualSearchHoverState)
                or use<<boolean>>(visualSearchFocusState)

            return if shouldShow then 0 else 1
        end),
        SearchHoverTweenInfo
    )
    local composedSearchStrokeTransparency = ComposeTransparency(
        scope,
        animatedSearchStrokeTransparency,
        contentTransparency
    )

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

    local scopeAlive = true
    table.insert(scope, function()
        scopeAlive = false
    end)

    local searchInput = CoreInput(scope, {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Text = searchState,
        PlaceholderText = searchPlaceholderText,
        TextColor3 = textColor,
        PlaceholderColor3 = placeholderColor,
        TextTransparency = contentTransparency,
        TextSize = fontSize,
        FontFace = font,
        ClearTextOnFocus = false,
        Interactable = effectiveSearchInteractable,
        TextEditable = effectiveSearchInteractable,
        TextXAlignment = Enum.TextXAlignment.Left,

        [Out "Text"] = searchState,
        [OnEvent "Focused"] = function()
            searchFocusState:set(true)
            if onSearchFocused then onSearchFocused() end
        end,
        [OnEvent "FocusLost"] = function(
            enterPressed: boolean,
            inputThatCausedFocusLoss: InputObject?
        )
            searchFocusState:set(false)
            if onSearchFocusLost then
                onSearchFocusLost(
                    enterPressed,
                    inputThatCausedFocusLoss
                )
            end
        end,

        [Children] = New(scope, "UIPadding") {
            PaddingLeft = UDim.new(0, 6),
            PaddingRight = UDim.new(0, 6)
        },

        Name = "Search"
    }) :: TextBox

    local searchBorder = TransparencyGated(
        scope,
        Supercorner.new :: any,
        {
            GatedTransparencyProperty = "StrokeTransparency",
            BackgroundTransparency = 1,
            StrokeColor = animatedSearchStrokeColor,
            StrokeTransparency = composedSearchStrokeTransparency,
            StrokeThickness = 1,
            Size = UDim2.new(1, 2, 1, 2),
            ZIndex = 3,
            TopLeftRadius = searchCornerRadius,
            TopRightRadius = searchCornerRadius,
            BottomLeftRadius = 0,
            BottomRightRadius = 0,
            Position = UDim2.fromScale(.5, .5),
            AnchorPoint = Vector2.new(.5, .5)
        }
    )

    local searchFocusRing = FocusRing(scope, {
        IsFocus = visualSearchFocusState,
        TransitionTweenInfo = FocusTransitionTweenInfo,
        BaseSize = UDim2.new(1, 2, 1, 2),
        TopLeftRadius = searchCornerRadius,
        TopRightRadius = searchCornerRadius,
        BottomLeftRadius = 0,
        BottomRightRadius = 0,
        Transparency = contentTransparency
    })

    local searchChrome = CoreFrame(
        scope,
        Supercorner.new :: any,
        {
            Size = ComputeUDim2(
                scope,
                UDim.new(1, 0),
                ComputeUDim(scope, 0, searchHeight)
            ),
            BackgroundTransparency = 1,
            TopLeftRadius = searchCornerRadius,
            TopRightRadius = searchCornerRadius,
            BottomLeftRadius = 0,
            BottomRightRadius = 0,
            Interactable = effectiveSearchInteractable,
            Visible = isSearchEnabled,
            ZIndex = 2,

            Name = "SearchChrome",

            [OnEvent "MouseEnter"] = function()
                searchHoverState:set(true)
            end,
            [OnEvent "MouseLeave"] = function()
                searchHoverState:set(false)
            end,

            RootChildren = {
                searchBorder,
                searchFocusRing
            } :: { Fusion.Child },

            [Children] = searchInput
        }
    )

    local rowCullTransparency = Computed(
        scope,
        function(use: Fusion.Use): number
            return if use<<boolean>>(renderVisible) then 0 else 1
        end
    )
    local renderedItems = TransparencyGated(
        scope,
        function(itemScope: Fusion.Scope, _props): Fusion.Child
            return Fusion.ForPairs(
                itemScope,
                filteredItems,
                function(
                    use,
                    itemScope,
                    key,
                    value
                )
                    local usedItem = value

                    return usedItem.Idx, SelectMenuItem(itemScope, {
                        Text = usedItem.Text,
                        SelectedIdxValue = selectedIdxValue,
                        Idx = usedItem.Idx,
                        LayoutOrder = key,
                        Transparency = contentTransparency,
                        Interactable = effectiveInteractable
                    })
                end
            ) :: Fusion.Child
        end,
        {
            GateTransparency = rowCullTransparency
        }
    )

    local selectMenu = Placement(scope, Container, CombineProps({
        Variant = variant,
        BackgroundTransparency = backgroundTransparency,
        StrokeColor = strokeColor,
        StrokeTransparency = strokeTransparency,
        Size = ComputeUDim2(scope, width, UDim.new(0, 0)),
        AutomaticSize = Enum.AutomaticSize.Y,
        ContentZIndex = 4,
        Position = preferredPosition,
        AnchorPoint = preferredAnchorPoint,
        Transparency = transparency,
        Visible = isVisible,
        OutRenderVisible = renderVisible,
        OutTransitionTransparency = transitionTransparency,

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
            searchChrome,

            New(scope, "Frame") {
                BackgroundColor3 = strokeColor,
                BackgroundTransparency = composedStrokeTransparency,
                BorderSizePixel = 0,
                Size = UDim2.new(1, 0, 0, SearchDividerHeight),
                Visible = isSearchEnabled,
                ZIndex = 1,

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
                        Transparency = contentTransparency,

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
                                TextTransparency = contentTransparency,
                                TextXAlignment = Enum.TextXAlignment.Center,
                                TextYAlignment = Enum.TextYAlignment.Center,
                                Visible = shouldShowEmptyText,

                                Name = "SelectMenuEmptyText"
                            }),

                            renderedItems,

                            New(scope, "UIListLayout") {
                                Padding = UDim.new(0, 1),
                                FillDirection = Enum.FillDirection.Vertical,
                                SortOrder = effectiveSortOrder,

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

    Observer(scope, effectiveSearchInteractable):onBind(function()
        if not Peek<<boolean>>(effectiveSearchInteractable) then return end

        task.defer(function()
            if not scopeAlive then return end
            if not Peek<<boolean>>(effectiveSearchInteractable) then return end
            if searchInput:IsFocused() then return end

            searchInput:CaptureFocus()
        end)
    end)

    return selectMenu
end)
