
--!strict

local Packages =
    script.Parent.Parent.Parent.Parent.Parent.Parent.Parent.Parent.packages
local Fusion = require(Packages.fusion)
local New, Children, Observer, OnEvent, Peek, Value =
    Fusion.New, Fusion.Children, Fusion.Observer,
    Fusion.OnEvent, Fusion.peek, Fusion.Value

local Utils = script.Parent.Parent.Parent.Parent.Parent.Parent.utils
local ThemeUtils = require(Utils.themeUtils)
local GetThemeForScope = ThemeUtils.GetThemeForScope

local Types = require(script.Parent.types)
local CreateSidePadding = require(script.Parent.utils.createSidePadding)

local Components = script.Parent.Parent.Parent.Parent.Parent
local SelectMenu = require(Components.selectMenu)
local Text = require(Components.text)

local MenuGap = 4
local MenuMaxHeight = 150

local function IsPointInside(guiObject: GuiObject, point: Vector3): boolean
    local topLeft = guiObject.AbsolutePosition
    local bottomRight = topLeft + guiObject.AbsoluteSize

    return point.X >= topLeft.X
        and point.X <= bottomRight.X
        and point.Y >= topLeft.Y
        and point.Y <= bottomRight.Y
end

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
                Variant = if props.Writable then "Primary" else "Secondary",
                Size = UDim2.fromScale(1, 0),
            }),

            CreateSidePadding(scope)
        } :: { Fusion.Child }
    end

    local enumItems = value.EnumType:GetEnumItems()
    local itemNames = table.create(#enumItems) :: { string }
    for idx, enumItem in enumItems do
        itemNames[idx] = enumItem.Name
    end

    local currentIdx = table.find(enumItems, value)
    local selectedIdxState = Value<<number?>>(scope, currentIdx)
    local displayedValueState = Value(scope, value.Name)
    local isFocusState = Value(scope, false)

    local textBox: TextBox
    local selectMenu: GuiObject

    local function setFocused(isFocused: boolean)
        if Peek<<boolean>>(isFocusState) == isFocused then return end

        isFocusState:set(isFocused)
        if props.OnFocusChanged then props.OnFocusChanged(isFocused) end
    end

    local function closeMenu()
        setFocused(false)
        if textBox:IsFocused() then textBox:ReleaseFocus(false) end
    end

    Observer(scope, selectedIdxState):onChange(function()
        local nextIdx = Peek<<number?>>(selectedIdxState)
        if nextIdx == currentIdx then return end

        local nextValue = if nextIdx == nil then nil else enumItems[nextIdx]
        if nextValue == nil then
            selectedIdxState:set(currentIdx)
            closeMenu()
            return
        end

        local success, err, savedValue = trySetValue(nextValue)
        if not success then
            selectedIdxState:set(currentIdx)
            closeMenu()
            warn(`SuperProperties: {err or "Could not set value."}`)
            return
        end

        local valueToDisplay =
            if savedValue ~= nil then savedValue else nextValue
        currentIdx = table.find(enumItems, valueToDisplay)
        displayedValueState:set(valueToDisplay.Name)

        if Peek<<number?>>(selectedIdxState) ~= currentIdx then
            selectedIdxState:set(currentIdx)
        end

        closeMenu()
    end)

    local theme = GetThemeForScope(scope)
    local textColor = theme:GetFg(scope, "Primary")
    local font = theme:GetFont(scope, "Main", Enum.FontWeight.Regular)
    local fontSize = theme:GetFontSize(scope, "Main", "Body")

    selectMenu = SelectMenu(scope, {
        Items = itemNames,
        SelectedIdx = selectedIdxState,
        MaxHeight = MenuMaxHeight,
        Position = UDim2.new(0, 0, 1, MenuGap),
        Visible = isFocusState,
        ZIndex = 2
    }) :: GuiObject

    textBox = New(scope, "TextBox") {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Text = displayedValueState,
        TextColor3 = textColor,
        FontFace = font,
        TextSize = fontSize,
        TextEditable = false,
        ClearTextOnFocus = false,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 1,

        Name = "EnumItemInput",

        [OnEvent "Focused"] = function()
            setFocused(true)
        end,

        [OnEvent "FocusLost"] = function(
            _enterPressed: boolean,
            inputThatCausedFocusLoss: InputObject?
        )
            if inputThatCausedFocusLoss ~= nil
                and IsPointInside(
                    selectMenu,
                    inputThatCausedFocusLoss.Position
                )
            then
                -- Clicking a menu option releases TextBox focus before the
                -- option's click event fires. Keep the menu mounted and
                -- restore focus if the interaction does not select an item.
                task.defer(function()
                    if Peek<<boolean>>(isFocusState) then
                        textBox:CaptureFocus()
                    end
                end)
                return
            end

            setFocused(false)
        end
    } :: TextBox

    return New(scope, "Frame") {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,

        Name = "EnumItemValue",

        [Children] = {
            New(scope, "Frame") {
                Size = UDim2.fromScale(1, 1),
                BackgroundTransparency = 1,

                Name = "EnumItemInputContainer",

                [Children] = ({
                    textBox,
                    CreateSidePadding(scope)
                } :: { Fusion.Child })
            },

            selectMenu,

            New(scope, "UIFlexItem") {}
        }
    }
end
