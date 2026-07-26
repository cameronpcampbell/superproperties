
--!strict

local Packages =
    script.Parent.Parent.Parent.Parent.Parent.Parent.Parent.Parent.packages
local Fusion = require(Packages.fusion)
local Computed, New, Children =
    Fusion.Computed, Fusion.New, Fusion.Children

local Types = require(script.Parent.types)
local CreateSidePadding = require(script.Parent.utils.createSidePadding)

local Components = script.Parent.Parent.Parent.Parent.Parent
local Text = require(Components.text)

return function(
    scope: Fusion.Scope,
    props: Types.ValueVariantProps<any>
): Fusion.Child
    local value = props.Value
    local text = Computed(scope, function(use: Fusion.Use): string
        if use<<boolean>>(props.Mixed) then return "" end
        return tostring(use<<any>>(value))
    end)

    return {
        Text(scope, {
            Text = text,
            TextColor3 = props.TextColor3,
            Size = UDim2.fromScale(1, 0),

            [Children] = New(scope, "UIFlexItem") {
                FlexMode = Enum.UIFlexMode.Shrink
            }
        }),

        CreateSidePadding(scope)
    } :: Fusion.Child
end
