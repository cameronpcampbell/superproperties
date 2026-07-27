--!strict

local Root = script.Parent.Parent.Parent.Parent.Parent.Parent
local Packages = Root.packages

local Fusion = require(Packages.fusion)
local Children, Computed, New, OnEvent, Tween, Value =
    Fusion.Children, Fusion.Computed, Fusion.New, Fusion.OnEvent,
    Fusion.Tween, Fusion.Value

local Mosaic = require(Packages.mosaic)
local Icon, Text, TransparencyGated =
    Mosaic.Icon, Mosaic.Text, Mosaic.TransparencyGated

local ValueVariantTypes = require(
    Packages.mosaic.components.map.item.value.variants.types
)
type ValueVariantProps<T> = ValueVariantTypes.ValueVariantProps<T>

local Assets = require(Root.assets)

local IconSize = 12
local SidePadding = 6
local ContentGap = 6
local TransitionTweenInfo = TweenInfo.new(
    .18,
    Enum.EasingStyle.Exponential,
    Enum.EasingDirection.InOut
)

return function(
    scope: Fusion.Scope,
    props: ValueVariantProps<string>
): Fusion.Child
    local hoverState = Value(scope, false)
    local hoverAlpha = Tween<<number>>(
        scope,
        Computed(scope, function(use: Fusion.Use): number
            return if use<<boolean>>(hoverState) then 1 else 0
        end),
        TransitionTweenInfo
    )
    local capabilityTransparency = Computed(
        scope,
        function(use: Fusion.Use): number
            return 1 - use<<number>>(hoverAlpha)
        end
    )
    local capabilityText = Computed(
        scope,
        function(use: Fusion.Use): string
            return `Needs {use<<string>>(props.Value)}.`
        end
    )

    local textGroup = New(scope, "Frame") {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        ClipsDescendants = true,
        LayoutOrder = 0,

        Name = "NotScriptableText",

        [Children] = ({
            TransparencyGated(scope, Text :: any, {
                GatedTransparencyProperty = "TextTransparency",
                Text = "Not scriptable.",
                TextColor3 = props.TextColor3,
                TextTransparency = hoverAlpha,
                FontStyle = Enum.FontStyle.Italic,
                Size = UDim2.fromScale(1, 1),
                AutomaticSize = Enum.AutomaticSize.None
            }),

            TransparencyGated(scope, Text :: any, {
                GatedTransparencyProperty = "TextTransparency",
                Text = capabilityText,
                TextColor3 = props.TextColor3,
                TextTransparency = capabilityTransparency,
                Size = UDim2.fromScale(1, 1),
                AutomaticSize = Enum.AutomaticSize.None
            }),

            New(scope, "UIFlexItem") {
                FlexMode = Enum.UIFlexMode.Shrink
            }
        } :: { Fusion.Child })
    }

    return New(scope, "Frame") {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,

        Name = "NotScriptableValue",

        [OnEvent "MouseEnter"] = function()
            hoverState:set(true)
        end,

        [OnEvent "MouseLeave"] = function()
            hoverState:set(false)
        end,

        [Children] = ({
            textGroup,

            Icon(scope, {
                Image = Assets.Warning,
                ImageColor3 = props.TextColor3,
                Size = UDim2.fromOffset(IconSize, IconSize),
                LayoutOrder = 1,

                Name = "WarningIcon"
            }),

            New(scope, "UIListLayout") {
                Padding = UDim.new(0, ContentGap),
                FillDirection = Enum.FillDirection.Horizontal,
                HorizontalFlex = Enum.UIFlexAlignment.SpaceBetween,
                VerticalAlignment = Enum.VerticalAlignment.Center,
                SortOrder = Enum.SortOrder.LayoutOrder
            },

            New(scope, "UIPadding") {
                PaddingLeft = UDim.new(0, SidePadding),
                PaddingRight = UDim.new(0, SidePadding)
            },

            New(scope, "UIFlexItem") {
                FlexMode = Enum.UIFlexMode.Shrink
            }
        } :: { Fusion.Child })
    }
end
