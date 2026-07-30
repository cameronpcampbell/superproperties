--!strict

local Packages =
    script.Parent.Parent.Parent.Parent.Parent.Parent.Parent.Parent.Parent.packages
local Fusion = require(Packages.fusion)
local Computed, New, Children, Observer, Value, Peek, Out, OnEvent =
    Fusion.Computed, Fusion.New, Fusion.Children, Fusion.Observer,
    Fusion.Value, Fusion.peek, Fusion.Out, Fusion.OnEvent

local Utils = script.Parent.Parent.Parent.Parent.Parent.Parent.Parent.utils
local FusionUtils = require(Utils.fusionUtils)
local CreateOutProxy = FusionUtils.CreateOutProxy

local ThemeUtils = require(Utils.themeUtils)
local GetThemeForScope = ThemeUtils.GetThemeForScope

local Types = require(script.Parent.Parent.types)
local CreateSidePadding = require(script.Parent.createSidePadding)

local Components = script.Parent.Parent.Parent.Parent.Parent.Parent
local CoreInput = require(Components.Parent.coreComponents.input)
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
        local formatFocused = config.FormatFocused
        local displayedValue = Computed(
            scope,
            function(use: Fusion.Use): string
                if use<<boolean>>(props.Mixed) then return "" end
                return config.Format(use<<T>>(value))
            end
        )

        if not props.Writable or trySetValue == nil then
            return {
                Text(scope, {
                    Text = displayedValue,
                    TextColor3 = props.TextColor3,
                    Size = UDim2.fromScale(1, 0),

                    [Children] = New(scope, "UIFlexItem") {
                        FlexMode = Enum.UIFlexMode.Shrink
                    }
                }),

                CreateSidePadding(scope)
            } :: Fusion.Child
        end

        local textState = Value<<string>>(
            scope,
            Peek<<string>>(displayedValue)
        )
        local editing = false
        local focusedValue = ""

        local function reportFocus(
            isFocused: boolean,
            parserFailed: boolean?
        )
            if props.OnFocusChanged then
                props.OnFocusChanged(isFocused, parserFailed)
            end
        end

        local textOutProxy = CreateOutProxy<<string>>(
            scope,
            textState,
            function(newText)
                textState:set(newText)
                if not editing then return end

                local parserFailed = false
                if newText ~= focusedValue then
                    local parsedValue = config.Parse(newText)
                    parserFailed = parsedValue == nil
                end

                reportFocus(true, parserFailed)
            end
        )

        local function syncDisplayedValue()
            if editing then return end
            textState:set(Peek<<string>>(displayedValue))
        end

        Observer(scope, displayedValue):onChange(syncDisplayedValue)

        local theme = GetThemeForScope(scope)
        local font = theme:GetFont(scope, "Main", Enum.FontWeight.Regular)
        local fontSize = theme:GetFontSize(scope, "Main", "Body")

        local textBox: TextBox
        textBox = CoreInput(scope, {
            Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1,
            Text = textState,
            TextColor3 = props.TextColor3,
            FontFace = font,
            TextSize = fontSize,
            ClearTextOnFocus = false,
            TextXAlignment = Enum.TextXAlignment.Left,
            ClipsDescendants = true,

            Name = config.InputName,

            [OnEvent "Focused"] = function()
                editing = true
                if Peek<<boolean>>(props.Mixed) then
                    focusedValue = ""
                else
                    local currentValue = Peek<<T>>(value)
                    focusedValue =
                        if formatFocused ~= nil
                        then formatFocused(currentValue)
                        else config.Format(currentValue)
                end
                textState:set(focusedValue)
                textBox.CursorPosition = #focusedValue + 1
                textBox.SelectionStart = 1

                reportFocus(true, false)
            end,

            [OnEvent "FocusLost"] = function()
                local nextText = Peek<<string>>(textState)
                if nextText == focusedValue then
                    reportFocus(false, false)
                    editing = false
                    syncDisplayedValue()
                    return
                end

                local nextValue, parseError = config.Parse(nextText)
                if nextValue == nil then
                    reportFocus(false, true)
                    editing = false
                    syncDisplayedValue()
                    warn(`SuperProperties: {parseError or "Invalid value."}`)
                    return
                end

                reportFocus(false, false)
                local success, err, savedValue = trySetValue(nextValue)
                editing = false
                if success then
                    local valueToDisplay =
                        if savedValue ~= nil then savedValue else nextValue

                    textState:set(config.Format(valueToDisplay))
                    return
                end

                syncDisplayedValue()
                warn(`SuperProperties: {err or "Could not set value."}`)
            end,

            [Out "Text"] = textOutProxy,

            [Children] = New(scope, "UIFlexItem") {
                FlexMode = Enum.UIFlexMode.Shrink
            }
        }) :: TextBox

        return {
            textBox :: Instance,
            CreateSidePadding(scope)
        } :: Fusion.Child
    end
end

return CreateTextVariant
