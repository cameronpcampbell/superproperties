--!strict
--!nolint LocalShadow

local Packages = script.Parent.Parent.Parent.Parent.Parent
local Supercorner = require(Packages.supercorner)
local Typeforge = require(Packages.typeforge)

local Fusion = require(Packages.fusion)
local New, Children, Peek = Fusion.New, Fusion.Children, Fusion.peek

local Utils = script.Parent.Parent.Parent.Parent.utils

local FusionUtils = require(Utils.fusionUtils)
local CombineProps = FusionUtils.CombineProps
local ComputeTransforms = FusionUtils.ComputeTransforms
local ComputeUDim2, ComputeUDim = ComputeTransforms.UDim2, ComputeTransforms.UDim
local ComputeMath = FusionUtils.ComputeMath
local ComputeAdd = ComputeMath.Add

local ThemeUtils = require(Utils.themeUtils)
local GetThemeForScope = ThemeUtils.GetThemeForScope

local Components = script.Parent.Parent.Parent
local CoreFrame = require(Components.Parent.coreComponents.frame)

local Types = require(script.Parent.Parent.types)

local CalculateRowCornerRadii = require(script.Parent.Parent.cornerRadii)
local CreateMapItemInteraction = require(script.Parent.interaction)

local ValueVariants = require(script.variants)
local DefaultValueVariant = ValueVariants.Default
type MapItemValueProps = Typeforge.Flatten<Types.BaseMapProps & {
	Value: Fusion.UsedAs<any>,
	ValueType: Types.ValueType,
	Mixed: Fusion.UsedAs<boolean>,
	TextColor3: Fusion.UsedAs<Color3>,
	Writable: boolean,
	TrySetValue: Types.TrySet<any>?,
	Redrawable: boolean,
	HoverState: Fusion.Value<boolean>?,
	FocusState: Fusion.Value<boolean>?,
	FocusElevationState: Fusion.Value<boolean>?,
	FocusRingAlphaState: Fusion.Value<number>?,
	RightChildren: Fusion.Child?,
}>

local function MapItemValue(scope: Fusion.Scope, props: MapItemValueProps)
	local rowCount, rowIdx = props.RowCount, props.RowIdx
	local variant = props.Variant
	local value = props.Value
	local currentValue = Peek<<any>>(value)
	local valueType = props.ValueType

	local valueVariant: ValueVariants.ValueVariantFn<any>
	if type(valueType) == "function" then
		valueVariant = valueType
	elseif currentValue == nil and valueType ~= "Instance" then
		valueVariant = DefaultValueVariant
	else
		valueVariant =
			(ValueVariants :: any)[valueType] or DefaultValueVariant
	end

	local theme = GetThemeForScope(scope)
	local bgColor = theme:GetBg(scope, variant)
	local rowHeight = ComputeAdd(scope, theme:GetHeight(scope, "Lg"), -2)
	local innerCornerRadius = ComputeAdd(scope, theme:GetCornerRadius(scope, "Md"), -1)

	local topLeftRadius, topRightRadius, bottomLeftRadius, bottomRightRadius =
		CalculateRowCornerRadii(scope, "Right", rowCount, rowIdx, props.Redrawable, innerCornerRadius)

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
		FocusRingAlphaState = props.FocusRingAlphaState,
	})

	return CoreFrame(
		scope,
		Supercorner.new :: any,
		CombineProps({
			BackgroundColor3 = bgColor,
			Size = ComputeUDim2(scope, UDim.new(1, 0), ComputeUDim(scope, 0, rowHeight)),
			TopLeftRadius = topLeftRadius,
			TopRightRadius = topRightRadius,
			BottomLeftRadius = bottomLeftRadius,
			BottomRightRadius = bottomRightRadius,
			MaxCornerRadius = if props.Redrawable then innerCornerRadius else nil,
			Redrawable = props.Redrawable,
			LayoutOrder = 1,

			Name = "MapItemValue",

			RootChildren = interaction.RootChildren,

			[Children] = {
				valueVariant(scope, {
					Value = value,
					Mixed = props.Mixed,
					TextColor3 = props.TextColor3,
					Writable = props.Writable,
					TrySetValue = props.TrySetValue,
					OnFocusChanged = interaction.OnFocusChanged,
					FocusState = props.FocusState,
					HoverState = props.HoverState,
				}),

				props.RightChildren,

				New(scope, "UIListLayout")({
					Padding = UDim.new(0, 6),
					FillDirection = Enum.FillDirection.Horizontal,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
			},
		}, interaction.InteractionProps)
	)
end

return MapItemValue
