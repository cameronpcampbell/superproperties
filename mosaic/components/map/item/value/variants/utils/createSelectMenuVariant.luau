--!strict

local Packages =
    script.Parent.Parent.Parent.Parent.Parent.Parent.Parent.Parent.Parent.packages
local Fusion = require(Packages.fusion)
local Computed, New, Children, Observer, OnEvent, Peek, Value =
    Fusion.Computed, Fusion.New, Fusion.Children, Fusion.Observer,
    Fusion.OnEvent, Fusion.peek, Fusion.Value

local Types = require(script.Parent.Parent.types)
local CreateSidePadding = require(script.Parent.createSidePadding)

local Components = script.Parent.Parent.Parent.Parent.Parent.Parent
local Icon = require(Components.icon)
local SelectMenu = require(Components.selectMenu)
local Text = require(Components.text)
local Assets = require(Components.Parent.assets)
local PopoverFocus = require(Components.Parent.coreComponents.popoverFocus)

type Metadata<T> = {
    Items: { SelectMenu.Item },
    GetIndex: (value: T) -> number?,
    ResolveValue: (idx: number, currentValue: T) -> T?
}

type Config<T> = {
    Name: string,
    GetMetadata: (initialValue: T) -> Metadata<T>,
    Format: (value: T) -> string,
    GetDisplayFontFace: ((value: T) -> Font)?,
    EnableSearch: boolean?,
    SortOrder: Enum.SortOrder?,
    SearchPlaceholderText: string?
}

local ChevronGap = 6
local ChevronWidth = 6
local MenuGap = 4
local MenuMaxHeight = 150
local PointerCursor = "rbxasset://SystemCursors/PointingHand"
local SidePadding = 6

local PluginInstance = script:FindFirstAncestorOfClass("Plugin") :: Plugin?
assert(PluginInstance, "Select menu variants must be created from inside a Plugin")
local PluginMouse = PluginInstance:GetMouse()

local function CreateSelectMenuVariant<T>(
    config: Config<T>
): Types.ValueVariantFn<T>
    return function(
        scope: Fusion.Scope,
        props: Types.ValueVariantProps<T>
    ): Fusion.Child
        local value = props.Value
        local trySetValue = props.TrySetValue
        local getDisplayFontFace = config.GetDisplayFontFace

        if not props.Writable or trySetValue == nil then
            local displayedValue = Computed(
                scope,
                function(use: Fusion.Use): string
                    if use<<boolean>>(props.Mixed) then return "" end
                    return config.Format(use<<T>>(value))
                end
            )
            local displayedFontFace =
                if getDisplayFontFace == nil then nil
                else Computed(
                    scope,
                    function(use: Fusion.Use): Font
                        return getDisplayFontFace(use<<T>>(value))
                    end
                )

            return {
                Text(scope, {
                    Text = displayedValue,
                    TextColor3 = props.TextColor3,
                    FontFace = displayedFontFace,
                    Size = UDim2.fromScale(1, 0),

                    [Children] = New(scope, "UIFlexItem") {
                        FlexMode = Enum.UIFlexMode.Shrink
                    }
                }),

                CreateSidePadding(scope)
            } :: Fusion.Child
        end

        local observedValue = Computed(
            scope,
            function(use: Fusion.Use): T
                return use<<T>>(value)
            end
        )
        local observedMixed = Computed(
            scope,
            function(use: Fusion.Use): boolean
                return use<<boolean>>(props.Mixed)
            end
        )
        local currentValue = Peek<<T>>(observedValue)
        local metadata = config.GetMetadata(currentValue)
        local currentIdx =
            if Peek<<boolean>>(observedMixed)
            then nil
            else metadata.GetIndex(currentValue)
        local selectedIdxState = Value<<number?>>(scope, currentIdx)
        local displayedValueState = Value(
            scope,
            if currentIdx == nil and Peek<<boolean>>(observedMixed)
            then ""
            else config.Format(currentValue)
        )
        local displayedFontFaceState =
            if getDisplayFontFace == nil then nil
            else Value<<Font>>(scope, getDisplayFontFace(currentValue))
        local selectedIdxStateAlive = true

        table.insert(scope, function()
            selectedIdxStateAlive = false
        end)

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

        local hitArea: TextButton
        local selectMenu: GuiObject
        local popoverFocus = PopoverFocus(scope, {
            GetInteractionRoots = function(): { GuiObject }
                return { selectMenu, hitArea }
            end,
            OnFocusChanged =
                if props.OnFocusChanged == nil then nil
                else function(isFocused: boolean)
                    props.OnFocusChanged(isFocused)
                end,
            Name = `{config.Name}FocusTarget`
        })
        local inputFocusState = popoverFocus.State
        local visualFocusState = props.FocusState or inputFocusState
        local previousMouseIcon: string? = nil
        local isHovering = false

        local function showPointer()
            if not isHovering then
                isHovering = true
                previousMouseIcon = PluginMouse.Icon
            end

            PluginMouse.Icon = PointerCursor
        end

        local function restorePointer()
            if not isHovering then return end
            isHovering = false

            if PluginMouse.Icon == PointerCursor then
                PluginMouse.Icon = previousMouseIcon or ""
            end

            previousMouseIcon = nil
        end

        table.insert(scope, restorePointer)

        local function closeMenu()
            popoverFocus.Release()
        end

        local function setDisplayedValue(nextValue: T)
            displayedValueState:set(config.Format(nextValue))

            if displayedFontFaceState and getDisplayFontFace then
                displayedFontFaceState:set(getDisplayFontFace(nextValue))
            end
        end

        local function syncObservedValue()
            local nextValue = Peek<<T>>(observedValue)
            local nextIsMixed = Peek<<boolean>>(observedMixed)
            local nextIdx =
                if nextIsMixed
                then nil
                else metadata.GetIndex(nextValue)

            currentIdx = nextIdx
            displayedValueState:set(
                if nextIsMixed then "" else config.Format(nextValue)
            )

            if displayedFontFaceState and getDisplayFontFace then
                displayedFontFaceState:set(getDisplayFontFace(nextValue))
            end

            if Peek<<number?>>(selectedIdxState) ~= nextIdx then
                selectedIdxState:set(nextIdx)
            end
        end

        Observer(scope, observedValue):onChange(syncObservedValue)
        Observer(scope, observedMixed):onChange(syncObservedValue)

        Observer(scope, selectedIdxState):onChange(function()
            local nextIdx = Peek<<number?>>(selectedIdxState)
            if nextIdx == currentIdx then return end

            local nextValue =
                if nextIdx == nil then nil
                else metadata.ResolveValue(
                    nextIdx,
                    Peek<<T>>(observedValue)
                )
            if nextValue == nil then
                deferSelectedIdxCorrection(nextIdx, currentIdx)
                closeMenu()
                return
            end

            local success, err, savedValue = trySetValue(nextValue)
            if not success then
                deferSelectedIdxCorrection(nextIdx, currentIdx)
                closeMenu()
                warn(`SuperProperties: {err or "Could not set value."}`)
                return
            end

            local valueToDisplay =
                if savedValue ~= nil then savedValue else nextValue
            currentIdx = metadata.GetIndex(valueToDisplay)
            setDisplayedValue(valueToDisplay)

            deferSelectedIdxCorrection(nextIdx, currentIdx)

            closeMenu()
        end)

        selectMenu = SelectMenu(scope, {
            Items = metadata.Items,
            SelectedIdx = selectedIdxState,
            EnableSearch = config.EnableSearch,
            SortOrder = config.SortOrder,
            SearchPlaceholderText = config.SearchPlaceholderText,
            Width = UDim.new(1, 2),
            MaxHeight = MenuMaxHeight,
            Position = UDim2.new(0, -1, 1, MenuGap),
            Visible = visualFocusState,
            Interactable = inputFocusState,
            OnSearchFocused = function()
                popoverFocus.ChildFocused()
            end,
            OnSearchFocusLost = function(
                _enterPressed: boolean,
                inputThatCausedFocusLoss: InputObject?
            )
                popoverFocus.ChildFocusLost(inputThatCausedFocusLoss)
            end,
            ZIndex = 4
        }) :: GuiObject

        local displayedValue = Text(scope, {
            Size = UDim2.fromScale(1, 1),
            AutomaticSize = Enum.AutomaticSize.None,
            Text = displayedValueState,
            TextColor3 = props.TextColor3,
            FontFace = displayedFontFaceState,
            ZIndex = 1,

            Name = `{config.Name}Text`
        }, {
            [Children] = New(scope, "UIPadding") {
                PaddingLeft = UDim.new(0, SidePadding),
                PaddingRight = UDim.new(
                    0,
                    SidePadding + ChevronWidth + ChevronGap
                )
            }
        })

        local chevrons = Icon(scope, {
            Image = Assets.ChevronsThin,
            Width = ChevronWidth,
            Position = UDim2.new(1, -SidePadding, .5, 0),
            AnchorPoint = Vector2.new(1, .5),
            ZIndex = 1,

            Name = `{config.Name}Chevrons`
        })

        hitArea = New(scope, "TextButton") {
            Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1,
            Text = "",
            AutoButtonColor = false,
            Selectable = false,
            ZIndex = 3,

            Name = `{config.Name}HitArea`,

            [OnEvent "MouseEnter"] = showPointer,
            [OnEvent "MouseMoved"] = showPointer,
            [OnEvent "MouseLeave"] = restorePointer,

            [OnEvent "Activated"] = function()
                popoverFocus.Capture()

                task.defer(function()
                    if isHovering then showPointer() end
                end)
            end
        } :: TextButton

        return New(scope, "Frame") {
            Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1,

            Name = `{config.Name}Value`,

            [Children] = ({
                displayedValue,

                chevrons,

                popoverFocus.Target,

                hitArea,

                selectMenu,

                New(scope, "UIFlexItem") {
                    FlexMode = Enum.UIFlexMode.Shrink
                }
            } :: { Fusion.Child })
        }
    end
end

return CreateSelectMenuVariant
