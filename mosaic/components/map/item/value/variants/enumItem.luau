
--!strict

local Packages =
    script.Parent.Parent.Parent.Parent.Parent.Parent.Parent.Parent.packages
local Fusion = require(Packages.fusion)
local New, Children, Observer, OnEvent, Peek, Value =
    Fusion.New, Fusion.Children, Fusion.Observer,
    Fusion.OnEvent, Fusion.peek, Fusion.Value

local Types = require(script.Parent.types)
local CreateSidePadding = require(script.Parent.utils.createSidePadding)

local Components = script.Parent.Parent.Parent.Parent.Parent
local Icon = require(Components.icon)
local SelectMenu = require(Components.selectMenu)
local Text = require(Components.text)
local Assets = require(Components.Parent.assets)
local PopoverFocus = require(Components.Parent.coreComponents.popoverFocus)

local ChevronGap = 6
local ChevronSize = 9
local MenuGap = 4
local MenuMaxHeight = 150
local PointerCursor = "rbxasset://SystemCursors/PointingHand"
local SidePadding = 6

local PluginInstance = script:FindFirstAncestorOfClass("Plugin") :: Plugin?
assert(PluginInstance, "EnumItem must be created from inside a Plugin")
local PluginMouse = PluginInstance:GetMouse()

return function(
    scope: Fusion.Scope,
    props: Types.ValueVariantProps<EnumItem>
): Fusion.Child
    local value = props.Value
    local trySetValue = props.TrySetValue

    if not props.Writable or trySetValue == nil then
        return {
            Text(scope, {
                Text = value.Name,
                Variant =
                    if props.DisplayAsWritable then "Primary"
                    else "Secondary",
                Size = UDim2.fromScale(1, 0),

                [Children] = New(scope, "UIFlexItem") {
                    FlexMode = Enum.UIFlexMode.Shrink
                }
            }),

            CreateSidePadding(scope)
        } :: Fusion.Child
    end

    local enumItems = value.EnumType:GetEnumItems()
    local itemNames = table.create(#enumItems) :: { string }
    for idx, enumItem in enumItems do
        itemNames[idx] = enumItem.Name
    end

    local currentIdx = table.find(enumItems, value)
    local selectedIdxState = Value<<number?>>(scope, currentIdx)
    local displayedValueState = Value(scope, value.Name)
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
        Name = "EnumItemFocusTarget"
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

    Observer(scope, selectedIdxState):onChange(function()
        local nextIdx = Peek<<number?>>(selectedIdxState)
        if nextIdx == currentIdx then return end

        local nextValue = if nextIdx == nil then nil else enumItems[nextIdx]
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
        currentIdx = table.find(enumItems, valueToDisplay)
        displayedValueState:set(valueToDisplay.Name)

        deferSelectedIdxCorrection(nextIdx, currentIdx)

        closeMenu()
    end)

    selectMenu = SelectMenu(scope, {
        Items = itemNames,
        SelectedIdx = selectedIdxState,
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
        ZIndex = 1,

        Name = "EnumItemText"
    }, {
        [Children] = New(scope, "UIPadding") {
            PaddingLeft = UDim.new(0, SidePadding),
            PaddingRight = UDim.new(
                0,
                SidePadding + ChevronSize + ChevronGap
            )
        }
    })

    local chevrons = Icon(scope, {
        Image = Assets.ChevronsThin,
        Size = UDim2.fromOffset(ChevronSize, ChevronSize),
        Position = UDim2.new(1, -SidePadding, .5, 0),
        AnchorPoint = Vector2.new(1, .5),
        ZIndex = 1,

        Name = "EnumItemChevrons"
    })

    hitArea = New(scope, "TextButton") {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        Selectable = false,
        ZIndex = 3,

        Name = "EnumItemHitArea",

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

        Name = "EnumItemValue",

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
