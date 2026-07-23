--!strict
--!nolint LocalShadow

local Packages = script.Parent.Parent.Parent.Parent.Parent
local Supercorner = require(Packages.supercorner)
local Typeforge = require(Packages.typeforge)

local Fusion = require(Packages.fusion)
local New, Children, OnEvent, Out, Peek, Value =
    Fusion.New, Fusion.Children, Fusion.OnEvent, Fusion.Out,
    Fusion.peek, Fusion.Value

local Utils = script.Parent.Parent.Parent.Parent.utils

local FusionUtils = require(Utils.fusionUtils)
local CombineProps = FusionUtils.CombineProps
local ComputeTransforms = FusionUtils.ComputeTransforms
local ComputeUDim2, ComputeUDim =
    ComputeTransforms.UDim2, ComputeTransforms.UDim
local ComputeMath = FusionUtils.ComputeMath
local ComputeAdd = ComputeMath.Add

local ThemeUtils = require(Utils.themeUtils)
local GetThemeForScope = ThemeUtils.GetThemeForScope

local Components = script.Parent.Parent.Parent
local Text = require(Components.text)
local CoreInput = require(Components.Parent.coreComponents.input)

local Assets = require(script.Parent.Parent.Parent.Parent.assets)
local Types = require(script.Parent.Parent.types)
local CalculateRowCornerRadii = require(script.Parent.Parent.cornerRadii)
local Arrow = require(script.Parent.Parent.arrow)
local CreateMapItemInteraction = require(script.Parent.interaction)

local IndicatorSize = 9
local IndicatorGap = 6

type MapItemKeyProps = Typeforge.Flatten<
    Types.BaseMapProps & {
        Key: string,
        Writable: boolean,
        DisplayAsWritable: boolean,
        TrySetKey: Types.TrySet<string>?,
        Side: "Left" | "Both",
        HasSubItems: boolean,
        Nestedness: number,
        CollapsedState: Fusion.Value<boolean>?,
        Redrawable: boolean,
        HoverState: Fusion.Value<boolean>?,
        FocusState: Fusion.Value<boolean>?,
        FocusElevationState: Fusion.Value<boolean>?,
        FocusRingAlphaState: Fusion.Value<number>?,
        RightChildren: Fusion.Child?
    }
>

local function MapItemKey(scope: Fusion.Scope, props: MapItemKeyProps)
    local rowCount, rowIdx = props.RowCount, props.RowIdx
    local variant = props.Variant
    local hasSubItems: boolean = props.HasSubItems
    local nestedness: number = props.Nestedness

    local leftPadding = IndicatorGap
        + math.max(nestedness - 1, 0) * (IndicatorSize + IndicatorGap)

    local theme = GetThemeForScope(scope)
    local bgColor = theme:GetBg(scope, variant)
    local dotColor = theme:GetFg(scope, "Tertiary")
    local rowHeight = ComputeAdd(scope, theme:GetHeight(scope, "Lg"), - 2)
    local innerCornerRadius = ComputeAdd(scope, theme:GetCornerRadius(scope, "Md"), - 1)

    local indicator: Fusion.Child
    if hasSubItems then
        indicator = Arrow(scope, {
            CollapsedState = props.CollapsedState :: Fusion.Value<boolean>,
            Variant =
                if props.DisplayAsWritable then "Primary"
                else "Secondary",
            Thin = true,
            LayoutOrder = 0
        })

    else
        indicator = New(scope, "ImageLabel") {
            Image = Assets.Dot,
            Size = UDim2.fromOffset(IndicatorSize, IndicatorSize),
            BackgroundTransparency = 1,
            ImageColor3 = dotColor,
            ImageTransparency = .5,
            LayoutOrder = 0
        }
    end

    local topLeftRadius, topRightRadius, bottomLeftRadius, bottomRightRadius =
        CalculateRowCornerRadii(
            scope,
            props.Side,
            rowCount,
            rowIdx,
            props.Redrawable,
            innerCornerRadius
        )

    local interaction = CreateMapItemInteraction(scope, {
        Variant = variant,
        Writable = props.Writable,
        Redrawable = props.Redrawable,
        TopLeftRadius = topLeftRadius,
        TopRightRadius = topRightRadius,
        BottomLeftRadius = bottomLeftRadius,
        BottomRightRadius = bottomRightRadius,
        MaxCornerRadius = innerCornerRadius,
        HoverState = props.HoverState,
        FocusState = props.FocusState,
        FocusElevationState = props.FocusElevationState,
        FocusRingAlphaState = props.FocusRingAlphaState
    })

    local keyContent: Fusion.Child
    local trySetKey = props.TrySetKey

    if props.Writable and trySetKey then
        local key = props.Key
        local textState = Value<<string>>(scope, key)
        local textColor = theme:GetFg(scope, "Primary")
        local font = theme:GetFont(scope, "Main", Enum.FontWeight.Regular)
        local fontSize = theme:GetFontSize(scope, "Main", "Body")
        local textBox: TextBox

        textBox = CoreInput(scope, {
            Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1,
            Text = textState,
            TextColor3 = textColor,
            FontFace = font,
            TextSize = fontSize,
            ClearTextOnFocus = false,
            TextXAlignment = Enum.TextXAlignment.Left,
            ClipsDescendants = true,
            LayoutOrder = 1,

            Name = "KeyInput",

            [OnEvent "Focused"] = function()
                textBox.CursorPosition = #key + 1
                textBox.SelectionStart = 1

                local onFocusChanged = interaction.OnFocusChanged
                if onFocusChanged then onFocusChanged(true) end
            end,

            [OnEvent "FocusLost"] = function()
                local onFocusChanged = interaction.OnFocusChanged
                if onFocusChanged then onFocusChanged(false) end

                local nextKey = Peek<<string>>(textState)
                if nextKey == key then return end

                local success, err, savedKey = trySetKey(nextKey)
                if success then
                    textState:set(savedKey or nextKey)
                    return
                end

                textState:set(key)
                warn(`SuperProperties: {err or "Could not set key."}`)
            end,

            [Out "Text"] = textState,

            [Children] = New(scope, "UIFlexItem") {
                FlexMode = Enum.UIFlexMode.Shrink
            }
        }) :: TextBox

        keyContent = textBox
    else
        keyContent = Text(scope, {
            Text = props.Key,
            Variant =
                if props.DisplayAsWritable then "Primary"
                else "Secondary",
            Size = UDim2.fromScale(1, 0),
            LayoutOrder = 1,

            [Children] = New(scope, "UIFlexItem") {
                FlexMode = Enum.UIFlexMode.Shrink
            }
        })
    end

    return Supercorner.new(scope, CombineProps({
        BackgroundColor3 = bgColor,
        Size = ComputeUDim2(scope, UDim.new(1, 0), ComputeUDim(scope, 0, rowHeight)),
        TopLeftRadius = topLeftRadius,
        TopRightRadius = topRightRadius,
        BottomLeftRadius = bottomLeftRadius,
        BottomRightRadius = bottomRightRadius,
        MaxCornerRadius = if props.Redrawable then innerCornerRadius else nil,
        Redrawable = props.Redrawable,
        LayoutOrder = 0,

        Name = "MapItemKey",

        RootChildren = interaction.RootChildren,

        [Children] = ({
            indicator,
            keyContent,

            props.RightChildren,

            New(scope, "UIListLayout") {
                Padding = UDim.new(0, IndicatorGap),
                FillDirection = Enum.FillDirection.Horizontal,
                VerticalAlignment = Enum.VerticalAlignment.Center,
                SortOrder = Enum.SortOrder.LayoutOrder
            },

            New(scope, "UIPadding") {
                PaddingLeft = UDim.new(0, leftPadding),
                PaddingRight = UDim.new(0, IndicatorGap)
            },
        } :: { Fusion.Child })
    }, interaction.InteractionProps))
end

return MapItemKey
