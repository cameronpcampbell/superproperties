
--!strict

local Packages =
    script.Parent.Parent.Parent.Parent.Parent.Parent.Parent.Parent.packages
local Fusion = require(Packages.fusion)
local New, Children, Value, Peek, Out, OnEvent =
    Fusion.New, Fusion.Children, Fusion.Value, Fusion.peek,
    Fusion.Out, Fusion.OnEvent

local Utils = script.Parent.Parent.Parent.Parent.Parent.Parent.utils
local ThemeUtils = require(Utils.themeUtils)
local GetThemeForScope = ThemeUtils.GetThemeForScope

local Types = require(script.Parent.types)

local Components = script.Parent.Parent.Parent.Parent.Parent
local Text = require(Components.text)

return function(scope: Fusion.Scope, props: Types.ValueVariantProps<string>)
    local value = props.Value
    local trySetValue = props.TrySetValue

    if not props.Writable or trySetValue == nil then
        return Text(scope, {
            Text = value,
            Variant = if props.Writable then "Primary" else "Secondary",
            Size = UDim2.fromScale(1, 0),
        })
    end

    local textState = Value<<string>>(scope, value)
    local theme = GetThemeForScope(scope)
    local textColor = theme:GetFg(scope, "Primary")
    local font = theme:GetFont(scope, "Main", Enum.FontWeight.Regular)
    local fontSize = theme:GetFontSize(scope, "Main", "Body")

    return New(scope, "TextBox") {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Text = textState,
        TextColor3 = textColor,
        FontFace = font,
        TextSize = fontSize,
        ClearTextOnFocus = false,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,

        Name = "StringValueInput",

        [OnEvent "Focused"] = function()
            if props.OnFocusChanged then props.OnFocusChanged(true) end
        end,

        [OnEvent "FocusLost"] = function()
            if props.OnFocusChanged then props.OnFocusChanged(false) end

            local nextValue = Peek<<string>>(textState)
            if nextValue == value then return end

            local success, err = trySetValue(nextValue)
            if success then return end

            textState:set(value)
            warn(`SuperProperties: {err or "Could not set value."}`)
        end,

        [Out "Text"] = textState,

        [Children] = New(scope, "UIFlexItem") {
            FlexMode = Enum.UIFlexMode.Shrink
        }
    }
end
