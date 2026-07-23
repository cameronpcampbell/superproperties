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
local PopoverFocus =
    require(Components.Parent.coreComponents.popoverFocus)

local Utils = Components.Parent.utils
local SelectionService = require(Utils.selectionService)

local Types = require(script.Parent.types)
local CreateSidePadding = require(script.Parent.utils.createSidePadding)

local SelectionSettleTime = .1

local function InputFinished(input: InputObject): boolean
    return
        input.UserInputState == Enum.UserInputState.End
        or input.UserInputState == Enum.UserInputState.Cancel
end

return function(
    scope: Fusion.Scope,
    props: Types.ValueVariantProps<Instance?>
): Fusion.Child
    local value = props.Value
    local trySetValue = props.TrySetValue
    local writable = props.Writable and trySetValue ~= nil

    local classIcon =
        if value then StudioService:GetClassIcon(value.ClassName) else nil

    local content = New(scope, "Frame") {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,

        Name = "InstanceValueContent",

        [Children] = {
            Text(scope, {
                Text = if value then value.Name else "nil",
                Variant =
                    if props.DisplayAsWritable then "Primary"
                    else "Secondary",
                Size = UDim2.fromScale(1, 0),
                LayoutOrder = 0,

                [Children] = New(scope, "UIFlexItem") {
                    FlexMode = Enum.UIFlexMode.Shrink
                }
            }),

            if classIcon then
                Icon(scope, {
                    Image = classIcon.Image,
                    Size = UDim2.fromOffset(13, 13),
                    ImageRectOffset = classIcon.ImageRectOffset,
                    ImageRectSize = classIcon.ImageRectSize
                })
                else {},

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
        local pickPending = false
        local activePickToken: SelectionService.PickToken? = nil
        local alive = true
        local cancelRevision = 0

        local hitArea: TextButton
        local popoverFocus: PopoverFocus.Controller

        local function CancelActivePick()
            local token = activePickToken
            if token then
                activePickToken = nil
                SelectionService:CancelPick(token)
            end
        end

        local function SchedulePickCancellation(
            inputThatCausedFocusLoss: InputObject?
        )
            local token = activePickToken
            if token == nil then return end

            cancelRevision += 1
            local revision = cancelRevision

            task.spawn(function()
                local input = inputThatCausedFocusLoss
                if input then
                    local inputStateChanged =
                        input:GetPropertyChangedSignal("UserInputState")

                    while alive and not InputFinished(input) do
                        inputStateChanged:Wait()
                    end
                end

                -- Explorer publishes its selection after releasing UI focus.
                task.wait(SelectionSettleTime)

                if not alive then return end
                if revision ~= cancelRevision then return end
                if activePickToken ~= token then return end

                CancelActivePick()
            end)
        end

        popoverFocus = PopoverFocus(scope, {
            GetInteractionRoots = function(): { GuiObject }
                return { hitArea }
            end,
            OnFocusChanged = function(
                isFocused: boolean,
                inputThatCausedFocusLoss: InputObject?
            )
                if isFocused then
                    cancelRevision += 1
                else
                    SchedulePickCancellation(inputThatCausedFocusLoss)
                end

                if props.OnFocusChanged then
                    props.OnFocusChanged(isFocused)
                end
            end,
            Name = "InstanceFocusTarget"
        })

        local function BeginPick()
            if pickPending then return end

            cancelRevision += 1
            local token: SelectionService.PickToken = {}
            activePickToken = token
            pickPending = true

            task.spawn(function()
                if not alive or activePickToken ~= token then
                    pickPending = false
                    return
                end

                local pickedInstance =
                    SelectionService:PickInstanceAsync(token, function()
                        if alive and activePickToken == token then
                            popoverFocus.Capture()
                        end
                    end)

                if activePickToken == token then
                    activePickToken = nil
                end

                pickPending = false
                if not alive then return end

                popoverFocus.Release()
                if pickedInstance == nil then return end

                local setValue = trySetValue
                if setValue == nil then return end

                local success, err = setValue(pickedInstance)
                if not success then
                    warn(`SuperProperties: {err or "Could not set value."}`)
                end
            end)
        end

        table.insert(scope, function()
            alive = false
            cancelRevision += 1
            CancelActivePick()
        end)

        hitArea = New(scope, "TextButton") {
            Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1,
            Text = "",
            AutoButtonColor = false,
            Selectable = false,
            ZIndex = 2,

            Name = "InstanceValueHitArea",

            [OnEvent "Activated"] = BeginPick
        } :: TextButton

        table.insert(children, popoverFocus.Target)
        table.insert(children, hitArea)
    end

    return New(scope, "Frame") {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,

        Name = "InstanceValue",

        [Children] = children
    }
end
