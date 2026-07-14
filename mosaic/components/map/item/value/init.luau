--!strict
--!nolint LocalShadow

local Packages = script.Parent.Parent.Parent.Parent.Parent
local Supercorner = require(Packages.supercorner)
local Typeforge = require(Packages.typeforge)

local Fusion = require(Packages.fusion)
local Peek, New, Children = Fusion.peek, Fusion.New, Fusion.Children

local Utils = script.Parent.Parent.Parent.Parent.utils

local ThemeUtils = require(Utils.themeUtils)
local GetThemeForScope = ThemeUtils.GetThemeForScope

local Components = script.Parent.Parent.Parent
local Text = require(Components.text)
local Checkbox = require(Components.checkbox)

local Types = require(script.Parent.Parent.types)
local CalculateRowCornerRadii =
    require(script.Parent.Parent.cornerRadii)

type MapItemValueProps = Typeforge.Flatten<
    Types.BaseMapProps & {
        Value: any
    }
>

local function MapItemValue(scope: Fusion.Scope, props: MapItemValueProps)
    local theme = Peek<<ThemeUtils.Theme>>(GetThemeForScope(scope))
    local rowHeight = theme:GetHeight("Lg") - 2
    local innerCornerRadius = theme:GetCornerRadius("Md") - 1

    local rowCount, rowIdx = props.RowCount, props.RowIdx
    local variant = props.Variant

    local topLeftRadius, topRightRadius, bottomLeftRadius, bottomRightRadius =
        CalculateRowCornerRadii(
            "Right",
            rowCount,
            rowIdx,
            innerCornerRadius
        )

    return Supercorner.new(scope, {
        BackgroundColor3 = theme:GetBg(scope, variant),
        Size = UDim2.new(1, 0, 0, rowHeight),
        TopLeftRadius = topLeftRadius,
        TopRightRadius = topRightRadius,
        BottomLeftRadius = bottomLeftRadius,
        BottomRightRadius = bottomRightRadius,
        LayoutOrder = 1,

        Name = "MapItemValue",

        [Children] = {
            if type(props.Value) == "boolean" then
                Checkbox(scope, {
                    Checked = props.Value
                })
            else
                Text(scope, {
                    Text =
                        if typeof(props.Value) == "EnumItem" then props.Value.Name
                        else tostring(props.Value),
                    Variant = "Primary",
                    Size = UDim2.fromScale(1, 0),
                }),

            New(scope, "UIListLayout") {
                Padding = UDim.new(0, 6),
                FillDirection = Enum.FillDirection.Horizontal,
                VerticalAlignment = Enum.VerticalAlignment.Center
            },

            New(scope, "UIPadding") {
                PaddingLeft = UDim.new(0, 6),
                PaddingRight = UDim.new(0, 6)
            }
        }
    })
end

return MapItemValue
