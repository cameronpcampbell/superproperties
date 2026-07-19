--!strict
--!nolint LocalShadow

local Packages = script.Parent.Parent.Parent
local Supercorner = require(Packages.supercorner)

local Fusion = require(Packages.fusion)
local New, Children, Value, Peek, Computed, Tween =
    Fusion.New, Fusion.Children, Fusion.Value,
    Fusion.peek, Fusion.Computed, Fusion.Tween

local Utils = script.Parent.Parent.utils

local FusionUtils = require(Utils.fusionUtils)
local Component, CombineProps, CoerceToValue, ComposeTransparency =
    FusionUtils.Component, FusionUtils.CombineProps,
    FusionUtils.CoerceToValue, FusionUtils.ComposeTransparency
local ComputeTransforms = FusionUtils.ComputeTransforms
local ComputeUDim2 = ComputeTransforms.UDim2

local ThemeUtils = require(Utils.themeUtils)
local GetThemeForScope, GetNextVariant, CalcColorModifier =
    ThemeUtils.GetThemeForScope, ThemeUtils.GetNextVariant,
    ThemeUtils.CalcColorModifier

local TableUtils = require(Utils.tableUtils)
local TableExtract = TableUtils.Extract

local Components = script.Parent.Parent.components
local Scrollable = require(Components.scrollable)

local SelectMenuItem = require(script.item)

type SelectMenuProps = {
	Variant: ThemeUtils.BgVariantSubLayer?,
	Width: Fusion.UsedAs<UDim>?,
	MaxHeight: Fusion.UsedAs<number>?,
	Items: Fusion.UsedAs<{ string }>,
	SelectedIdx: Fusion.UsedAs<number?>?,
	DefaultIdx: Fusion.UsedAs<number>?,
	Visible: Fusion.UsedAs<boolean>?,
	Interactable: Fusion.UsedAs<boolean>?
}

local VisibilityTweenInfo = TweenInfo.new(
    .23,
    Enum.EasingStyle.Quint,
    Enum.EasingDirection.InOut
)

return Component<<SelectMenuProps>>(function(scope, props)
    local props, variant = TableExtract(props, "Variant", "Tertiary")
    local props, width = TableExtract(props, "Width", UDim.new(1, 0))
    local props, maxHeight = TableExtract(props, "MaxHeight", math.huge)
    local props, items = TableExtract(props, "Items")
    local props, selectedIdx = TableExtract(props, "SelectedIdx")
    local props, defaultIdx = TableExtract(props, "DefaultIdx")
    local props, visible = TableExtract(props, "Visible", true)
    local props, interactable = TableExtract(props, "Interactable", true)
    local props, backgroundTransparency =
        TableExtract(props, "BackgroundTransparency", 0)
    local props, strokeTransparency =
        TableExtract(props, "StrokeTransparency", 0)

    local isHoverState, isFocusState = Value(scope, false), Value(scope, false)
    local themeColorModifier =
        CalcColorModifier(scope, isHoverState, isFocusState, "Stroke")

    local selectedIdxValue = CoerceToValue<<number?>>(scope, selectedIdx)
    local visibilityTransparency = Tween<<number>>(
        scope,
        Computed(scope, function(use): number
            return if use<<boolean>>(visible) then 0 else 1
        end),
        VisibilityTweenInfo
    )
    local shouldRender = Computed(scope, function(use): boolean
        return
            use<<boolean>>(visible)
            or use<<number>>(visibilityTransparency) < .999
    end)
    local effectiveInteractable = Computed(scope, function(use): boolean
        return
            use<<boolean>>(visible)
            and use<<boolean>>(interactable)
    end)

    local theme = GetThemeForScope(scope)
    local bgColor = theme:GetBg(scope, variant)
    local strokeColor =
        theme:GetBg(scope, GetNextVariant(scope, variant), themeColorModifier)
    local cornerRadius = theme:GetCornerRadius(scope, "Md")
    local composedBackgroundTransparency = ComposeTransparency(
        scope,
        backgroundTransparency,
        visibilityTransparency
    )
    local composedStrokeTransparency = ComposeTransparency(
        scope,
        strokeTransparency,
        visibilityTransparency
    )

    return Supercorner.new(scope :: any, CombineProps({
        BackgroundColor3 = bgColor,
        BackgroundTransparency = composedBackgroundTransparency,
        StrokeColor = strokeColor,
        StrokeTransparency = composedStrokeTransparency,
        StrokeThickness = 1,
        Size = ComputeUDim2(scope, width, UDim.new(0, 0)),
        AutomaticSize = Enum.AutomaticSize.Y,
        CornerRadius = Peek<<number>>(cornerRadius),
        CornerSmoothing = 1,
        Visible = shouldRender,

        Name = "SelectMenu",

        RootChildren = {
            New(scope, "UIFlexItem") {},

            New(scope, "UISizeConstraint") {
                MaxSize = Computed(scope, function(use: Fusion.Use, scope)
                    return Vector2.new(math.huge, use<<number>>(maxHeight))
                end)
            },
        },

        [Children] = {
            Scrollable(scope, {
                Variant = GetNextVariant(scope, variant),
                Size = UDim2.new(1, 0, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                PaddingRight = UDim.new(0, 3),
                Transparency = visibilityTransparency,

                RootChildren = New(scope, "UISizeConstraint") {
                    MaxSize = Computed(scope, function(use: Fusion.Use)
                        return Vector2.new(
                            math.huge,
                            math.max(use<<number>>(maxHeight) - 8, 0)
                        )
                    end)
                },

                [Children] = {
                    Fusion.ForPairs(scope, items, function(use, scope, key, value)
                        return key, SelectMenuItem(scope, {
                            Text = value,
                            SelectedIdxValue = selectedIdxValue,
                            DefaultIdx = defaultIdx,
                            Idx = key,
                            Transparency = visibilityTransparency,
                            Interactable = effectiveInteractable
                        })
                    end),

                    New(scope, "UIListLayout") {
                        Padding = UDim.new(0, 1),
                        FillDirection = Enum.FillDirection.Vertical,
                        SortOrder = Enum.SortOrder.LayoutOrder
                    },
                }
            }),

            New(scope, "UIPadding") {
                PaddingLeft = UDim.new(0, 4),
                PaddingRight = UDim.new(0, 4),
                PaddingTop = UDim.new(0, 4),
                PaddingBottom = UDim.new(0, 4),
            },
        }
    }, props))
end)
