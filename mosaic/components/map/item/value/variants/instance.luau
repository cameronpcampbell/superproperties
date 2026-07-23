--!strict

local StudioService = game:GetService("StudioService")

local Packages =
    script.Parent.Parent.Parent.Parent.Parent.Parent.Parent.Parent.packages

local Fusion = require(Packages.fusion)
local Computed, New, Children, OnEvent, Tween =
    Fusion.Computed, Fusion.New, Fusion.Children, Fusion.OnEvent,
    Fusion.Tween

local Components = script.Parent.Parent.Parent.Parent.Parent
local Text = require(Components.text)
local Icon = require(Components.icon)
local PopoverFocus =
    require(Components.Parent.coreComponents.popoverFocus)
local Assets = require(Components.Parent.assets)

local Utils = Components.Parent.utils
local SelectionService = require(Utils.selectionService)

local Types = require(script.Parent.types)
local CreateSidePadding = require(script.Parent.utils.createSidePadding)
local HoverTweenInfo = require(script.Parent.Parent.Parent.hoverTweenInfo)

local SelectionSettleTime = .1
local InstanceIconSize = 13

local function InputFinished(input: InputObject): boolean
    return
        input.UserInputState == Enum.UserInputState.End
        or input.UserInputState == Enum.UserInputState.Cancel
end

local function CreateClearTransparency(
    scope: Fusion.Scope,
    hoverState: Fusion.Value<boolean>
): Fusion.Tween<number>
    return Tween<<number>>(
        scope,
        Computed(scope, function(use: Fusion.Use): number
            return if use<<boolean>>(hoverState) then 0 else 1
        end),
        HoverTweenInfo
    )
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

    local function TryCommitValue(nextValue: Instance?)
        local setValue = trySetValue
        if setValue == nil then return end

        local success, err = setValue(nextValue)
        if not success then
            warn(`SuperProperties: {err or "Could not set value."}`)
        end
    end

    local clearValue: (() -> ())? = nil
    local interactionChildren = {} :: { Fusion.Child }

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

                TryCommitValue(pickedInstance)
            end)
        end

        clearValue = function()
            cancelRevision += 1
            CancelActivePick()
            popoverFocus.Release()
            TryCommitValue(nil)
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

        table.insert(interactionChildren, popoverFocus.Target)
        table.insert(interactionChildren, hitArea)
    end

    local indicator: Fusion.Child = {}
    local hoverState = props.HoverState

    if value and writable and hoverState then
        local clearTransparency =
            CreateClearTransparency(scope, hoverState)
        local instanceIconTransparency = Computed(
            scope,
            function(use: Fusion.Use): number
                return 1 - use<<number>>(clearTransparency)
            end
        )
        local clearInteractable = Computed(
            scope,
            function(use: Fusion.Use): boolean
                return use<<boolean>>(hoverState)
            end
        )

        indicator = New(scope, "Frame") {
            Size = UDim2.fromOffset(InstanceIconSize, InstanceIconSize),
            BackgroundTransparency = 1,
            LayoutOrder = 1,

            Name = "InstanceValueIndicator",

            [Children] = {
                if classIcon then
                    Icon(scope, {
                        Image = classIcon.Image,
                        Size = UDim2.fromScale(1, 1),
                        ImageRectOffset = classIcon.ImageRectOffset,
                        ImageRectSize = classIcon.ImageRectSize,
                        ImageTransparency = instanceIconTransparency
                    })
                    else {},

                Icon(scope, {
                    Image = Assets.Cross,
                    Position = UDim2.fromScale(.5, .5),
                    AnchorPoint = Vector2.new(.5, .5),
                    ImageTransparency = clearTransparency,
                    ZIndex = 3,

                    Name = "InstanceValueClearIcon"
                }),

                New(scope, "TextButton") {
                    Size = UDim2.fromOffset(21, 21),
                    Position = UDim2.fromScale(.5, .5),
                    AnchorPoint = Vector2.new(.5, .5),
                    BackgroundTransparency = 1,
                    Text = "",
                    AutoButtonColor = false,
                    Selectable = false,
                    Interactable = clearInteractable,
                    ZIndex = 4,

                    Name = "InstanceValueClearButton",

                    [OnEvent "Activated"] = function()
                        local callback = clearValue
                        if callback then callback() end
                    end
                }
            }
        }
    elseif classIcon then
        indicator = Icon(scope, {
            Image = classIcon.Image,
            Size = UDim2.fromOffset(
                InstanceIconSize,
                InstanceIconSize
            ),
            ImageRectOffset = classIcon.ImageRectOffset,
            ImageRectSize = classIcon.ImageRectSize,
            LayoutOrder = 1
        })
    end

    local content = New(scope, "Frame") {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        ZIndex = 3,

        Name = "InstanceValueContent",

        [Children] = {
            Text(scope, {
                Text = if value then value.Name else "Empty",
                Variant =
                    if props.DisplayAsWritable then "Primary"
                    else "Secondary",
                FontStyle =
                    if value then Enum.FontStyle.Normal
                    else Enum.FontStyle.Italic,
                Size = UDim2.fromScale(1, 0),
                LayoutOrder = 0,

                [Children] = New(scope, "UIFlexItem") {
                    FlexMode = Enum.UIFlexMode.Shrink
                }
            }),

            indicator,

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

    for _, child in interactionChildren do
        table.insert(children, child)
    end

    return New(scope, "Frame") {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,

        Name = "InstanceValue",

        [Children] = children
    }
end
