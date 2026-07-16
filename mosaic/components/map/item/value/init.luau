--!strict
--!nolint LocalShadow

local Packages = script.Parent.Parent.Parent.Parent.Parent
local Supercorner = require(Packages.supercorner)
local Typeforge = require(Packages.typeforge)

local Fusion = require(Packages.fusion)
local New, Children = Fusion.New, Fusion.Children

local Utils = script.Parent.Parent.Parent.Parent.utils

local FusionUtils = require(Utils.fusionUtils)
local ComputeTransforms = FusionUtils.ComputeTransforms
local ComputeUDim2, ComputeUDim = ComputeTransforms.UDim2, ComputeTransforms.UDim
local ComputeMath = FusionUtils.ComputeMath
local ComputeAdd = ComputeMath.Add

local ThemeUtils = require(Utils.themeUtils)
local GetThemeForScope = ThemeUtils.GetThemeForScope

local Types = require(script.Parent.Parent.types)
local CalculateRowCornerRadii =
    require(script.Parent.Parent.cornerRadii)

local ValueVariants = require(script.variants)
local DefaultValueVariant = ValueVariants.string

type MapItemValueProps = Typeforge.Flatten<
    Types.BaseMapProps & {
        Value: any,
        Writable: boolean,
        TrySetValue: Types.TrySetValue<any>?,
        Redrawable: boolean
    }
>

local function MapItemValue(scope: Fusion.Scope, props: MapItemValueProps)
    local rowCount, rowIdx = props.RowCount, props.RowIdx
    local variant = props.Variant
    local value = props.Value

    local valueVariant: ValueVariants.ValueVariantFn<any> =
        (ValueVariants :: any)[typeof(value)] or
        DefaultValueVariant

    local theme = GetThemeForScope(scope)
    local bgColor = theme:GetBg(scope, variant)
    local rowHeight =
        ComputeAdd(scope, theme:GetHeight(scope, "Lg"), - 2)
    local innerCornerRadius =
        ComputeAdd(scope, theme:GetCornerRadius(scope, "Md"), - 1)

    local topLeftRadius, topRightRadius, bottomLeftRadius, bottomRightRadius =
        CalculateRowCornerRadii(
            scope,
            "Right",
            rowCount,
            rowIdx,
            props.Redrawable,
            innerCornerRadius
        )

    return Supercorner.new(scope, {
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

        [Children] = {
            valueVariant(scope, {
                Value = value,
                Writable = props.Writable,
                TrySetValue = props.TrySetValue
            }),

            New(scope, "UIListLayout") {
                Padding = UDim.new(0, 6),
                FillDirection = Enum.FillDirection.Horizontal,
                VerticalAlignment = Enum.VerticalAlignment.Center,
                SortOrder = Enum.SortOrder.LayoutOrder
            },

            New(scope, "UIPadding") {
                PaddingLeft = UDim.new(0, 6),
                PaddingRight = UDim.new(0, 6)
            }
        }
    })
end

return MapItemValue
