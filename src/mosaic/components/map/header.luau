--!strict
--!nolint LocalShadow

local Packages = script.Parent.Parent.Parent.Parent.packages
local Fusion = require(Packages.fusion)
local Typeforge = require(Packages.typeforge)

local Assets = require(script.Parent.Parent.Parent.assets)

local Utils = script.Parent.Parent.Parent.utils
local ThemeUtils = require(Utils.themeUtils)

local Components = script.Parent.Parent
local Text = require(Components.text)
local IconButton = require(Components.iconButton)

local Supercorner = require(Packages.supercorner)

local Types = require(script.Parent.types)

local Peek, New, Children, OnEvent = Fusion.peek, Fusion.New, Fusion.Children, Fusion.OnEvent
local GetThemeForScope = ThemeUtils.GetThemeForScope

type MapHeaderProps = Typeforge.Flatten<
    Types.BaseMapProps & {
        Header: string,
        MapCollapsedState: Fusion.Value<boolean>,
        TweenComputeMapSize: Fusion.Tween<UDim2>
    }
>

local function CalcCornerRadii(
    scope: Fusion.Scope,
    itemCount: number,
    itemIdx: number,
    baseRadius: number,
    tweenComputeMapSize: Fusion.Tween<UDim2>
): (
    Fusion.Computed<number>, Fusion.Computed<number>,
    Fusion.Computed<number>, Fusion.Computed<number>
)
    local theme = Peek<<ThemeUtils.Theme>>(GetThemeForScope(scope))
    local lgHeight = theme:GetHeight("Lg")

    local function cornerRadius(roundFirst: boolean, roundLast: boolean)
        return Fusion.Computed(scope, function(use, scope): number
            local usedTweenComputeMapSize = use<<UDim2>>(tweenComputeMapSize)
            local usedTweenComputeMapHeightOffset = usedTweenComputeMapSize.Height.Offset

            local itemCount =
                if usedTweenComputeMapHeightOffset == lgHeight then 1 else itemCount

            if roundFirst and itemIdx == 1 then
                return baseRadius
            end

            if roundLast and itemIdx == itemCount then
                return baseRadius
            end

            return 0
        end)
    end

    return
        cornerRadius(true, false),
        cornerRadius(true, false),
        cornerRadius(false, true),
        cornerRadius(false, true)
end

local function MapHeader(scope: Fusion.Scope, props: MapHeaderProps)
    local theme = Peek<<ThemeUtils.Theme>>(GetThemeForScope(scope))

    local itemCount, itemIdx = props.ItemCount, props.ItemIdx
    local variant = props.Variant
    local mapCollapsedState = props.MapCollapsedState
    local tweenComputeMapSize = props.TweenComputeMapSize

    -- We subtract 1 as this squircle is inset by 1px.
    local maxCornerRadius = theme:GetCornerRadius("Md") - 1

    local topLeftRadius, topRightRadius, bottomLeftRadius, bottomRightRadius =
        CalcCornerRadii(scope, itemCount, itemIdx, maxCornerRadius, tweenComputeMapSize)

    return Supercorner.new(scope, {
        BackgroundColor3 = theme:GetBgHighlight(scope, variant),
        -- We subtract 2 to account for the for the extra stroke that will be added.
        Size = UDim2.new(1, 0, 0, theme:GetHeight("Lg") - 2),
        LayoutOrder = itemIdx,
        TopLeftRadius = topLeftRadius,
        TopRightRadius = topRightRadius,
        BottomLeftRadius = bottomLeftRadius,
        BottomRightRadius = bottomRightRadius,
        MaxCornerRadius = maxCornerRadius,
        Redrawable = true,

        Name = "MapHeader",

        [Children] = {
            IconButton(scope, {
                Image = Assets.Arrow,
                Rotation = Fusion.Tween<<number>>(
                    scope,
                    Fusion.Computed(scope, function(use, scope)
                        return if use(mapCollapsedState) then -90 else 0
                    end) :: any,
                    TweenInfo.new(
                        .25, Enum.EasingStyle.Exponential, Enum.EasingDirection.InOut
                    )
                ),

                [OnEvent "MouseButton1Click"] = function()
                    mapCollapsedState:set(not Peek<<bool>>(mapCollapsedState))
                end
            }),

            Text(scope, {
                Text = props.Header,
                FontWeight = Enum.FontWeight.Medium
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

return MapHeader
