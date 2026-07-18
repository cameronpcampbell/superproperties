--!strict

local Packages =
    script.Parent.Parent.Parent.Parent.Parent.Parent.Parent.Parent.Parent.packages
local Fusion = require(Packages.fusion)
local New, Children, Value, Peek, Out, OnEvent, Computed =
    Fusion.New, Fusion.Children, Fusion.Value, Fusion.peek,
    Fusion.Out, Fusion.OnEvent, Fusion.Computed

local Utils = script.Parent.Parent.Parent.Parent.Parent.Parent.Parent.utils
local ThemeUtils = require(Utils.themeUtils)
local GetThemeForScope = ThemeUtils.GetThemeForScope

local Types = require(script.Parent.Parent.types)
local CreateSidePadding = require(script.Parent.createSidePadding)

local Components = script.Parent.Parent.Parent.Parent.Parent.Parent
local Text = require(Components.text)

type TextVariantConfig<T> = {
    InputName: string,
    Format: (value: T) -> string,
    FormatFocused: ((value: T) -> string)?,
    Parse: (text: string) -> (T?, string?)
}

local function CreateTextVariant<T>(
    config: TextVariantConfig<T>
): Types.ValueVariantFn<T>
    return function(
        scope: Fusion.Scope,
        props: Types.ValueVariantProps<T>
    ): Fusion.Child
        local value = props.Value
        local trySetValue = props.TrySetValue
        local displayedValue = config.Format(value)
        local formatFocused = config.FormatFocused
        local focusedValue =
            if formatFocused ~= nil then formatFocused(value) else displayedValue

        if not props.Writable or trySetValue == nil then
            return {
                Text(scope, {
                    Text = displayedValue,
                    Variant = if props.Writable then "Primary" else "Secondary",
                    Size = UDim2.fromScale(1, 0),
                }),

                CreateSidePadding(scope)
            } :: { Fusion.Child }
        end

        local textState = Value<<string>>(scope, displayedValue)
        local isFocusState = Value(scope, false)
        local textTruncate = Computed(scope, function(use)
            return
                if use<<boolean>>(isFocusState) then
                    Enum.TextTruncate.None
                else
                    Enum.TextTruncate.AtEnd
        end)
        local theme = GetThemeForScope(scope)
        local textColor = theme:GetFg(scope, "Primary")
        local font = theme:GetFont(scope, "Main", Enum.FontWeight.Regular)
        local fontSize = theme:GetFontSize(scope, "Main", "Body")

        local textBox: TextBox
        textBox = New(scope, "TextBox") {
            Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1,
            Text = textState,
            TextColor3 = textColor,
            FontFace = font,
            TextSize = fontSize,
            ClearTextOnFocus = false,
            TextXAlignment = Enum.TextXAlignment.Left,
            ClipsDescendants = true,
            TextTruncate = textTruncate,

            Name = config.InputName,

            [OnEvent "Focused"] = function()
                isFocusState:set(true)
                textState:set(focusedValue)
                textBox.CursorPosition = #focusedValue + 1
                textBox.SelectionStart = 1

                if props.OnFocusChanged then props.OnFocusChanged(true) end
            end,

            [OnEvent "FocusLost"] = function()
                isFocusState:set(false)
                if props.OnFocusChanged then props.OnFocusChanged(false) end

                local nextText = Peek<<string>>(textState)
                if nextText == focusedValue then
                    textState:set(displayedValue)
                    return
                end

                local nextValue, parseError = config.Parse(nextText)
                if nextValue == nil then
                    textState:set(displayedValue)
                    warn(`SuperProperties: {parseError or "Invalid value."}`)
                    return
                end

                local success, err, savedValue = trySetValue(nextValue)
                if success then
                    local valueToDisplay =
                        if savedValue ~= nil then savedValue else nextValue

                    textState:set(config.Format(valueToDisplay))
                    return
                end

                textState:set(displayedValue)
                warn(`SuperProperties: {err or "Could not set value."}`)
            end,

            [Out "Text"] = textState,

            [Children] = New(scope, "UIFlexItem") {
                FlexMode = Enum.UIFlexMode.Shrink
            }
        } :: TextBox

        return {
            textBox,
            CreateSidePadding(scope)
        } :: { Fusion.Child }
    end
end

return CreateTextVariant
