--!strict

local StudioService = game:GetService("StudioService")

local Packages =
    script.Parent.Parent.Parent.Parent.Parent.Parent.Parent.Parent.packages

local Fusion = require(Packages.fusion)
local New, Children, OnEvent =
    Fusion.New, Fusion.Children, Fusion.OnEvent

local Components = script.Parent.Parent.Parent.Parent.Parent
local Text = require(Components.text)
local Icon = require(Components.icon)

local Utils = Components.Parent.utils
local SelectionService = require(Utils.selectionService)

local Types = require(script.Parent.types)
local CreateSidePadding = require(script.Parent.utils.createSidePadding)

return function(
    scope: Fusion.Scope,
    props: Types.ValueVariantProps<Instance>
): Fusion.Child
    local value = props.Value
    local trySetValue = props.TrySetValue
    local writable = props.Writable and trySetValue ~= nil

    local classIcon = StudioService:GetClassIcon(value.ClassName)

    local pickPending = false
    local alive = true

    table.insert(scope, function()
        alive = false
    end)

    local function SetFocused(focused: boolean)
        if props.OnFocusChanged then
            props.OnFocusChanged(focused)
        end
    end

    local function BeginPick()
        if not writable or pickPending then return end

        pickPending = true
        SetFocused(true)

        task.spawn(function()
            local pickedInstance =
                SelectionService:PickInstanceAsync()

            pickPending = false
            if not alive then return end

            SetFocused(false)
            if pickedInstance == nil then return end

            local setValue = trySetValue
            if setValue == nil then return end

            local success, err = setValue(pickedInstance)
            if not success then
                warn(`SuperProperties: {err or "Could not set value."}`)
            end
        end)
    end

    local content = New(scope, "Frame") {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,

        Name = "InstanceValueContent",

        [Children] = {
            Text(scope, {
                Text = value.Name,
                Variant =
                    if props.DisplayAsWritable then "Primary"
                    else "Secondary",
                Size = UDim2.fromScale(1, 0),
                LayoutOrder = 0,

                [Children] = New(scope, "UIFlexItem") {
                    FlexMode = Enum.UIFlexMode.Shrink
                }
            }),

            Icon(scope, {
                Image = classIcon.Image,
                Size = UDim2.fromOffset(13, 13),
                ImageRectOffset = classIcon.ImageRectOffset,
                ImageRectSize = classIcon.ImageRectSize
            }),

            CreateSidePadding(scope),

            New(scope, "UIListLayout") {
                Padding = UDim.new(0, 6),
                FillDirection = Enum.FillDirection.Horizontal,
                VerticalAlignment = Enum.VerticalAlignment.Center,
                SortOrder = Enum.SortOrder.LayoutOrder
            }
        }
    }

    local children = {
        content,

        New(scope, "UIFlexItem") {
            FlexMode = Enum.UIFlexMode.Shrink
        }
    } :: { Fusion.Child }

    if writable then
        table.insert(children, New(scope, "TextButton") {
            Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1,
            Text = "",
            AutoButtonColor = false,
            Selectable = false,
            ZIndex = 2,

            Name = "InstanceValueHitArea",

            [OnEvent "Activated"] = BeginPick
        })
    end

    return New(scope, "Frame") {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,

        Name = "InstanceValue",

        [Children] = children
    }
end
