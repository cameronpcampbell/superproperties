--!strict

local Packages =
    script.Parent.Parent.Parent.Parent.Parent.Parent.Parent.Parent.packages
local Fusion = require(Packages.fusion)
local Computed, New, Children, Observer, Value, Peek, OnEvent =
    Fusion.Computed, Fusion.New, Fusion.Children, Fusion.Observer,
    Fusion.Value, Fusion.peek, Fusion.OnEvent

local Types = require(script.Parent.types)
local CreateSidePadding = require(script.Parent.utils.createSidePadding)

local Components = script.Parent.Parent.Parent.Parent.Parent
local Checkbox = require(Components.checkbox)
local GetNextChecked = require(Components.checkbox.getNextChecked)

return function(
    scope: Fusion.Scope,
    props: Types.ValueVariantProps<Checkbox.Checked>
): Fusion.Child
    local trySetValue = props.TrySetValue
    local observedValue = Computed(
        scope,
        function(use: Fusion.Use): Checkbox.Checked
            if use<<boolean>>(props.Mixed) then return "Mixed" end
            return use<<Checkbox.Checked>>(props.Value)
        end
    )
    local checkedState = Value(scope, Peek<<Checkbox.Checked>>(observedValue))
    local disabled = not props.Writable or trySetValue == nil

    Observer(scope, observedValue):onChange(function()
        checkedState:set(Peek<<Checkbox.Checked>>(observedValue))
    end)

    local function trySetChecked(value: boolean)
        if disabled then return end

        local setValue = trySetValue
        if setValue == nil then return end

        local success, err, savedValue = setValue(value)
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

        [Children] = ({
            New(scope, "TextButton") {
                Size = UDim2.fromScale(1, 1),
                BackgroundTransparency = 1,
                Text = "",
                AutoButtonColor = false,
                ZIndex = 1,

                [OnEvent "MouseButton1Click"] = function()
                    trySetChecked(
                        GetNextChecked(
                            Peek<<Checkbox.Checked>>(checkedState)
                        )
                    )
                end,

                Name = "HitArea"
            },

            New(scope, "Frame") {
                Size = UDim2.fromScale(1, 1),
                BackgroundTransparency = 1,
                ZIndex = 2,

                Name = "CheckboxContainer",

                [Children] = ({
                    Checkbox(scope, {
                        Checked = checkedState,
                        Disabled = disabled,
                        OnChanged = trySetChecked,
                        Position = UDim2.fromScale(0, 0.5),
                        AnchorPoint = Vector2.new(0, 0.5),
                        ZIndex = 2
                    }),

                    CreateSidePadding(scope)
                } :: { Fusion.Child })
            },

            New(scope, "UIFlexItem") {
                FlexMode = Enum.UIFlexMode.Shrink
            }
        } :: { Fusion.Child })
    }
end
