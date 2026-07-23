--!strict
--!nolint LocalShadow

local Packages = script.Parent.Parent.Parent
local Supercorner = require(Packages.supercorner)

local Fusion = require(Packages.fusion)
local New, Children, Value, Peek, Computed, Observer, OnEvent =
    Fusion.New, Fusion.Children, Fusion.Value, Fusion.peek,
    Fusion.Computed, Fusion.Observer, Fusion.OnEvent

local Utils = script.Parent.Parent.utils

local FusionUtils = require(Utils.fusionUtils)
local Component, CombineProps, CoerceToValue, Oktween =
    FusionUtils.Component, FusionUtils.CombineProps,
    FusionUtils.CoerceToValue, FusionUtils.Oktween
local ComputeTransforms = FusionUtils.ComputeTransforms
local ComputeUDim2, ComputeUDim =
    ComputeTransforms.UDim2, ComputeTransforms.UDim

local ThemeUtils = require(Utils.themeUtils)
local GetThemeForScope, GetNextVariant, CalcColorModifier =
    ThemeUtils.GetThemeForScope, ThemeUtils.GetNextVariant,
    ThemeUtils.CalcColorModifier

local TableUtils = require(Utils.tableUtils)
local TableExtract = TableUtils.Extract

local CoreComponents = script.Parent.Parent.coreComponents
local CoreButton = require(CoreComponents.button)
local PopoverFocus = require(CoreComponents.popoverFocus)

local Components = script.Parent.Parent.components
local FocusRing = require(Components.focusRing)
local Icon = require(Components.icon)
local SelectMenu = require(Components.selectMenu)
local Text = require(Components.text)

local Assets = require(script.Parent.Parent.assets)

type SelectProps = {
    Variant: ThemeUtils.BgVariantLayer?,
    Width: UDim?,
    Items: Fusion.UsedAs<{ string }>,
    SelectedIdx: Fusion.UsedAs<number?>?,
    PlaceholderText: Fusion.UsedAs<string>?,
    MenuMaxHeight: Fusion.UsedAs<number>?,
    OnFocusChanged: ((boolean, InputObject?) -> ())?,
    ParentPopoverFocus: PopoverFocus.Controller?,
    ZIndex: Fusion.UsedAs<number>?
}

local ElevatedZIndexOffset = 4
local MenuGap = 4
local MenuMaxHeight = 150

local function NewTextButton(
    scope: Fusion.Scope,
    props: { [any]: any }
): Fusion.Child
    return New(scope, "TextButton")(props)
end

return Component<<SelectProps>>(function(scope, props)
    local props, variant = TableExtract(props, "Variant", "Tertiary")
    local props, width = TableExtract(props, "Width", UDim.new(1, 0))
    local props, items = TableExtract(props, "Items")
    local props, selectedIdx = TableExtract(props, "SelectedIdx")
    local props, placeholderText =
        TableExtract(props, "PlaceholderText", "Select an item...")
    local props, menuMaxHeight =
        TableExtract(props, "MenuMaxHeight", MenuMaxHeight)
    local props, onFocusChanged =
        TableExtract(props, "OnFocusChanged")
    local props, parentPopoverFocus =
        TableExtract(props, "ParentPopoverFocus")
    local props, zIndex = TableExtract(props, "ZIndex", 1)

    local selectedIdxState =
        CoerceToValue<<number?>>(scope, selectedIdx)
    local isHoverState = Value(scope, false)
    local menuRenderVisibleState = Value(scope, false)
    local currentIdx = Peek<<number?>>(selectedIdxState)
    local selectedIdxStateAlive = true

    table.insert(scope, function()
        selectedIdxStateAlive = false
    end)

    local selectMenu: GuiObject
    local hitArea: TextButton
    local popoverFocus: PopoverFocus.Controller
    popoverFocus = PopoverFocus(scope, {
        GetInteractionRoots = function(): { GuiObject }
            return { selectMenu, hitArea }
        end,
        OnFocusChanged = function(
            isFocused: boolean,
            inputThatCausedFocusLoss: InputObject?
        )
            if parentPopoverFocus then
                if isFocused then
                    parentPopoverFocus.ChildFocused(popoverFocus.Target)
                elseif inputThatCausedFocusLoss ~= nil then
                    parentPopoverFocus.ChildFocusLost(
                        inputThatCausedFocusLoss
                    )
                elseif Peek<<boolean>>(parentPopoverFocus.State) then
                    -- Selecting an item releases this popover without an
                    -- outside click. Return focus to the parent popover.
                    parentPopoverFocus.Capture()
                end
            end

            if onFocusChanged then
                onFocusChanged(isFocused, inputThatCausedFocusLoss)
            end
        end,
        Name = "SelectFocusTarget"
    })
    local isFocusState = popoverFocus.State

    local function deferSelectedIdxCorrection(
        observedIdx: number?,
        correctedIdx: number?
    )
        if observedIdx == correctedIdx then return end

        task.defer(function()
            if not selectedIdxStateAlive then return end
            if Peek<<number?>>(selectedIdxState) ~= observedIdx then return end

            selectedIdxState:set(correctedIdx)
        end)
    end

    Observer(scope, selectedIdxState):onChange(function()
        local nextIdx = Peek<<number?>>(selectedIdxState)

        if not Peek<<boolean>>(isFocusState) then
            currentIdx = nextIdx
            return
        end

        local nextItem =
            if nextIdx == nil then nil
            else Peek<<{ string }>>(items)[nextIdx]
        if nextItem == nil then
            deferSelectedIdxCorrection(nextIdx, currentIdx)
            popoverFocus.Release()
            return
        end

        currentIdx = nextIdx
        popoverFocus.Release()
    end)

    local themeColorModifier =
        CalcColorModifier(scope, isHoverState, isFocusState, "Stroke")

    local theme = GetThemeForScope(scope)
    local bgColor = theme:GetBg(scope, variant)
    local primaryTextColor = theme:GetFg(scope, "Primary")
    local secondaryTextColor = theme:GetFg(scope, "Secondary")
    local accentColor = theme:GetAccent(scope, "Primary", themeColorModifier)
    local strokeColor = theme:GetBg(
        scope,
        GetNextVariant(scope, variant),
        themeColorModifier
    )
    local height = theme:GetHeight(scope, "Lg")
    local cornerRadius = theme:GetCornerRadius(scope, "Md")

    local isElevated = Computed(scope, function(use): boolean
        return
            use<<boolean>>(isFocusState)
            or use<<boolean>>(menuRenderVisibleState)
    end)

    local effectiveZIndex = Computed(scope, function(use): number
        local usedZIndex = use<<number>>(zIndex)

        return
            if use<<boolean>>(isElevated) then
                usedZIndex + ElevatedZIndexOffset
            else usedZIndex
    end)

    local hitAreaZIndex = Computed(scope, function(use): number
        return use<<number>>(effectiveZIndex) + 2
    end)

    local menuZIndex = Computed(scope, function(use): number
        return use<<number>>(effectiveZIndex) + 3
    end)

    local displayedText = Computed(scope, function(use): string
        local idx = use<<number?>>(selectedIdxState)
        local usedItems = use<<{ string }>>(items)

        return
            if idx ~= nil and usedItems[idx] ~= nil then usedItems[idx]
            else use<<string>>(placeholderText)
    end)

    local displayedTextColor = Computed(scope, function(use): Color3
        local idx = use<<number?>>(selectedIdxState)
        local usedItems = use<<{ string }>>(items)

        return
            if idx ~= nil and usedItems[idx] ~= nil then
                use<<Color3>>(primaryTextColor)
            else use<<Color3>>(secondaryTextColor)
    end)

    local tweenComputeStrokeColor = Oktween(
        scope,
        Computed(scope, function(use)
            return
                if use<<boolean>>(isFocusState) then
                    use<<Color3>>(accentColor)
                else use<<Color3>>(strokeColor)
        end),
        TweenInfo.new(
            .18,
            Enum.EasingStyle.Exponential,
            Enum.EasingDirection.InOut
        )
    )

    selectMenu = SelectMenu(scope, {
        Variant = variant,
        Items = items,
        SelectedIdx = selectedIdxState,
        Width = UDim.new(1, 2),
        MaxHeight = menuMaxHeight,
        Position = UDim2.new(0, -1, 1, MenuGap),
        Visible = isFocusState,
        Interactable = isFocusState,
        OutRenderVisible = menuRenderVisibleState,
        ZIndex = menuZIndex
    }) :: GuiObject

    local menuHost = New(scope, "Frame") {
        Size = UDim2.fromScale(1, 1),
        Position = UDim2.fromScale(0, 0),
        AutomaticSize = Enum.AutomaticSize.None,
        BackgroundTransparency = 1,
        ClipsDescendants = false,
        ZIndex = menuZIndex,

        Name = "SelectMenuHost",

        [Children] = selectMenu
    }

    local content = New(scope, "Frame") {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        ZIndex = effectiveZIndex,

        Name = "SelectContent",

        [Children] = {
            Text(scope, {
                Size = UDim2.fromScale(1, 1),
                AutomaticSize = Enum.AutomaticSize.None,
                Text = displayedText,
                TextColor3 = displayedTextColor,
                FontWeight = Enum.FontWeight.Medium,
                FontSize = "Title",
                LayoutOrder = 1,

                Name = "SelectText",

                [Children] = New(scope, "UIFlexItem") {
                    FlexMode = Enum.UIFlexMode.Shrink
                }
            }),

            Icon(scope, {
                Image = Assets.ChevronsThin,
                Width = 6,
                LayoutOrder = 2,

                Name = "SelectChevrons"
            }),

            New(scope, "UIListLayout") {
                FillDirection = Enum.FillDirection.Horizontal,
                HorizontalAlignment = Enum.HorizontalAlignment.Left,
                VerticalAlignment = Enum.VerticalAlignment.Center,
                SortOrder = Enum.SortOrder.LayoutOrder,
                Padding = UDim.new(0, 6)
            },

            New(scope, "UIPadding") {
                PaddingLeft = UDim.new(0, 7),
                PaddingRight = UDim.new(0, 7)
            }
        }
    }

    hitArea = CoreButton(scope, NewTextButton, {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        Selectable = false,
        ZIndex = hitAreaZIndex,

        Name = "SelectHitArea",

        [OnEvent "MouseEnter"] = function()
            isHoverState:set(true)
        end,

        [OnEvent "MouseLeave"] = function()
            isHoverState:set(false)
        end,

        [OnEvent "Activated"] = function()
            popoverFocus.Capture()
        end
    }) :: TextButton

    return Supercorner.new(scope :: any, CombineProps({
        BackgroundColor3 = bgColor,
        StrokeColor = tweenComputeStrokeColor,
        StrokeThickness = 1,
        Size = ComputeUDim2(scope, width, ComputeUDim(scope, 0, height)),
        AutomaticSize = Enum.AutomaticSize.None,
        CornerRadius = Peek<<number>>(cornerRadius),
        CornerSmoothing = 1,
        ZIndex = effectiveZIndex,

        Name = "Select",

        RootChildren = {
            New(scope, "UIFlexItem") {},

            FocusRing(scope, {
                IsFocus = isFocusState,
                CornerRadius = Peek<<number>>(cornerRadius)
            })
        },

        [Children] = {
            content,
            popoverFocus.Target,
            hitArea,
            menuHost
        }
    }, props))
end)
