--!strict
--!nolint LocalShadow

local Packages = script.Parent.Parent.Parent
local Supercorner = require(Packages.supercorner)

local Fusion = require(Packages.fusion)
local New, Children, Value, Peek, Out, OnEvent, Computed, Observer =
    Fusion.New, Fusion.Children, Fusion.Value, Fusion.peek,
    Fusion.Out, Fusion.OnEvent, Fusion.Computed, Fusion.Observer

local Utils = script.Parent.Parent.utils

local FusionUtils = require(Utils.fusionUtils)
local Component, CombineProps, ComposeTransparency, CreateOutProxy, IsValue,
    Oktween =
    FusionUtils.Component, FusionUtils.CombineProps,
    FusionUtils.ComposeTransparency, FusionUtils.CreateOutProxy,
    FusionUtils.IsValue, FusionUtils.Oktween
local ComputeTransforms = FusionUtils.ComputeTransforms
local ComputeUDim2, ComputeUDim = ComputeTransforms.UDim2, ComputeTransforms.UDim

local ThemeUtils = require(Utils.themeUtils)
local GetThemeForScope, GetNextVariant, CalcColorModifier =
    ThemeUtils.GetThemeForScope, ThemeUtils.GetNextVariant,
    ThemeUtils.CalcColorModifier

local TableUtils = require(Utils.tableUtils)
local TableExtract = TableUtils.Extract

local CoreComponents = script.Parent.Parent.coreComponents
local CoreFrame = require(CoreComponents.frame)
local CoreInput = require(CoreComponents.input)
local PopoverFocus = require(CoreComponents.popoverFocus)

local Components = script.Parent.Parent.components
local FocusRing = require(Components.focusRing)

type InputProps = {
	Variant: ThemeUtils.BgVariantLayer?,
	Text: (Fusion.UsedAs<string?>)?,
	PlaceholderText: Fusion.UsedAs<string>?,
	TextTruncate: Fusion.UsedAs<Enum.TextTruncate>?,
	Width: UDim?,
	LeftChildren: Fusion.Child?,
	RightChildren: Fusion.Child?,
	ParentPopoverFocus: PopoverFocus.Controller?,
	FocusState: Fusion.Value<boolean>?,
    Transparency: Fusion.UsedAs<number>?,
}

local function CreateAccessoryContainer(
    scope: Fusion.Scope,
    name: string,
    layoutOrder: number,
    children: Fusion.Child?
): Fusion.Child?
    if children == nil then return nil end

    return New(scope, "Frame") {
        Size = UDim2.fromScale(0, 1),
        AutomaticSize = Enum.AutomaticSize.X,
        BackgroundTransparency = 1,
        LayoutOrder = layoutOrder,
        Name = name,

        [Children] = {
            children,

            New(scope, "UIListLayout") {
                FillDirection = Enum.FillDirection.Horizontal,
                VerticalAlignment = Enum.VerticalAlignment.Center,
                SortOrder = Enum.SortOrder.LayoutOrder,
                Padding = UDim.new(0, 6)
            }
        }
    }
end

return Component<<InputProps>>(function(scope, props)
    local props, variant = TableExtract(props, "Variant", "Tertiary")
    local props, text = TableExtract(props, "Text", "")
    local props, placeholderText = TableExtract(props, "PlaceholderText", "Type here...")
    local props, textTruncate =
        TableExtract(props, "TextTruncate", Enum.TextTruncate.AtEnd)
    local props, width = TableExtract(props, "Width", UDim.new(1, 0))
    local props, leftChildren = TableExtract(props, "LeftChildren")
    local props, rightChildren = TableExtract(props, "RightChildren")
    local props, parentPopoverFocus =
        TableExtract(props, "ParentPopoverFocus")
    local props, focusState = TableExtract(props, "FocusState")
    local props, transparency =
        TableExtract(props, "Transparency", 0)
    local props, backgroundTransparency =
        TableExtract(props, "BackgroundTransparency", 0)
    local props, strokeTransparency =
        TableExtract(props, "StrokeTransparency", 0)
    local props, textTransparency =
        TableExtract(props, "TextTransparency", 0)

    local isHoverState, isFocusState = Value(scope, false), Value(scope, false)
    local themeColorModifier =
        CalcColorModifier(scope, isHoverState, isFocusState, "Stroke")

    local computeVisualText = Computed(scope, function(use, scope): string
        local usedText = use<<string?>>(text :: any)
        return usedText or ""
    end)
    local textValue = if IsValue(text) then
        (text :: any) :: Fusion.Value<string?, string>
        else nil

    local theme = GetThemeForScope(scope)
    local bgColor = theme:GetBg(scope, variant)
    local textColor = theme:GetFg(scope, "Primary")
    local textPlaceholderColor = theme:GetFg(scope, "Secondary")
    local accentColor = theme:GetAccent(scope, "Primary", themeColorModifier)
    local strokeColor = theme:GetBg(scope, GetNextVariant(scope, variant), themeColorModifier)
    local height = theme:GetHeight(scope, "Lg")
    local cornerRadius = theme:GetCornerRadius(scope, "Md")
    local font = theme:GetFont(scope, "Main", Enum.FontWeight.Medium)
    local fontSize = theme:GetFontSize(scope, "Main", "Title")

    local tweenComputeStrokeColor = Oktween(
        scope,
        Computed(scope, function(use, scope)
            return
                if use<<boolean>>(isFocusState) then
                    use<<Color3>>(accentColor)
                else
                    use<<Color3>>(strokeColor)
        end),
        TweenInfo.new(
            .18, Enum.EasingStyle.Exponential, Enum.EasingDirection.InOut
        )
    )
    local composedBackgroundTransparency = ComposeTransparency(
        scope,
        backgroundTransparency,
        transparency
    )
    local composedStrokeTransparency = ComposeTransparency(
        scope,
        strokeTransparency,
        transparency
    )
    local composedTextTransparency = ComposeTransparency(
        scope,
        textTransparency,
        transparency
    )

    local textOutProxy =
        if textValue then
            CreateOutProxy<<string>>(
                scope,
                computeVisualText,
                function(newText) textValue:set(newText) end
            )
        else nil

    local input: TextBox

    input = CoreInput(scope, {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Text = computeVisualText,
        PlaceholderText = placeholderText,
        TextSize = fontSize,
        TextColor3 = textColor,
        PlaceholderColor3 = textPlaceholderColor,
        TextTransparency = composedTextTransparency,
        FontFace = font,
        ClearTextOnFocus = false,
        ClipsDescendants = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = textTruncate,
        LayoutOrder = 1,

        [OnEvent "Focused"] = function()
            isFocusState:set(true)
            if parentPopoverFocus then
                parentPopoverFocus.ChildFocused(input)
            end
        end,

        [OnEvent "FocusLost"] = function(
            _enterPressed: boolean,
            inputThatCausedFocusLoss: InputObject?
        )
            isFocusState:set(false)
            if parentPopoverFocus then
                parentPopoverFocus.ChildFocusLost(
                    inputThatCausedFocusLoss
                )
            end
        end,

        [Out "Text"] = textOutProxy,

        [Children] = New(scope, "UIFlexItem") {
            FlexMode = Enum.UIFlexMode.Shrink
        }
    }) :: TextBox

    if parentPopoverFocus
        and focusState == parentPopoverFocus.State
    then
        table.insert(
            scope :: { Fusion.Task },
            parentPopoverFocus.RegisterDefaultChild(input) :: any
        )
    elseif focusState then
        Observer(scope, focusState):onBind(function()
            if not Peek<<boolean>>(focusState) then return end
            if input:IsFocused() then return end

            input:CaptureFocus()
        end)
    end

    return CoreFrame(scope, Supercorner.new :: any, CombineProps({
        BackgroundColor3 = bgColor,
        BackgroundTransparency = composedBackgroundTransparency,
        StrokeColor = tweenComputeStrokeColor,
        StrokeThickness = 1,
        StrokeTransparency = composedStrokeTransparency,
        Size = ComputeUDim2(scope, width, ComputeUDim(scope, 0, height)),
        CornerRadius = Peek<<number>>(cornerRadius),
        CornerSmoothing = 1,

        Name = "Input",

        [OnEvent "MouseEnter"] = function() isHoverState:set(true) end,
        [OnEvent "MouseLeave"] = function() isHoverState:set(false) end,

        RootChildren = {
            New(scope, "UIFlexItem") {},

            FocusRing(scope, {
                IsFocus = isFocusState,
                Transparency = transparency,
                -- Focus ring's corner radius can't be changed.
                CornerRadius = Peek<<number>>(cornerRadius)
            })
        },

        [Children] = {
            CreateAccessoryContainer(
                scope,
                "LeftChildren",
                0,
                leftChildren
            ),

            input,

            CreateAccessoryContainer(
                scope,
                "RightChildren",
                2,
                rightChildren
            ),

            New(scope, "UIListLayout") {
                FillDirection = Enum.FillDirection.Horizontal,
                HorizontalAlignment = Enum.HorizontalAlignment.Left,
                VerticalAlignment = Enum.VerticalAlignment.Center,
                SortOrder = Enum.SortOrder.LayoutOrder,
                Padding = UDim.new(0, 6)
            },

            New(scope, "UIPadding") {
                PaddingLeft = UDim.new(0, 7),
                PaddingRight = UDim.new(0, 7),
            },
        }
    }, props))
end)
