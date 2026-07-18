--!strict

local Packages =
    script.Parent.Parent.Parent.Parent.Parent.Parent.Parent.Parent.packages
local Fusion = require(Packages.fusion)
local New, Children, Value, Peek, OnEvent =
    Fusion.New, Fusion.Children, Fusion.Value, Fusion.peek, Fusion.OnEvent

local Types = require(script.Parent.types)

local Components = script.Parent.Parent.Parent.Parent.Parent
local Checkbox = require(Components.checkbox)

return function(scope: Fusion.Scope, props: Types.ValueVariantProps<boolean>)
    local trySetValue = props.TrySetValue
    local checkedState = Value(scope, props.Value)
    local disabled = not props.Writable or trySetValue == nil

    local function trySetChecked(value: boolean)
        if disabled or not trySetValue then return end

        local success, err, savedValue = trySetValue(value)
        if success then
            checkedState:set(
                if savedValue ~= nil then savedValue else value
            )
            return
        end

        warn(`SuperProperties: {err or "Could not set value."}`)
    end

    return New(scope, "Frame") {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,

        Name = "BooleanValue",

        [Children] = {
            New(scope, "TextButton") {
                Size = UDim2.fromScale(1, 1),
                BackgroundTransparency = 1,
                Text = "",
                AutoButtonColor = false,
                ZIndex = 1,

                [OnEvent "MouseButton1Click"] = function()
                    trySetChecked(not Peek<<boolean>>(checkedState))
                end,

                Name = "HitArea"
            },

            Checkbox(scope, {
                Checked = checkedState,
                Disabled = disabled,
                OnChanged = trySetChecked,
                Position = UDim2.fromScale(0, 0.5),
                AnchorPoint = Vector2.new(0, 0.5),
                ZIndex = 2
            }),

            New(scope, "UIFlexItem") {}
        }
    }
end
