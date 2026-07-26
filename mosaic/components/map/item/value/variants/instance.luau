--!strict

local StudioService = game:GetService("StudioService")

local Packages =
    script.Parent.Parent.Parent.Parent.Parent.Parent.Parent.Parent.packages

local Fusion = require(Packages.fusion)
local Computed, New, Children, OnEvent, Peek, Tween =
    Fusion.Computed, Fusion.New, Fusion.Children, Fusion.OnEvent,
    Fusion.peek, Fusion.Tween

local Components = script.Parent.Parent.Parent.Parent.Parent
local Text = require(Components.text)
local Icon = require(Components.icon)
local IconButton = require(Components.iconButton)
local PopoverFocus =
    require(Components.Parent.coreComponents.popoverFocus)
local Assets = require(Components.Parent.assets)

local Utils = Components.Parent.utils
local SelectionService = require(Utils.selectionService)

local Types = require(script.Parent.types)
local InstanceHandle = require(script.Parent["instanceHandle.types"])
type InstanceHandle = InstanceHandle.InstanceHandle
type InstanceValue = Instance | InstanceHandle | nil

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
    props: Types.ValueVariantProps<InstanceValue>
): Fusion.Child
    local initialStoredValue = Peek<<InstanceValue>>(props.Value)
    local storedValueType = typeof(initialStoredValue) :: string
    local usesInstanceHandle = storedValueType == "InstanceHandle"
    local value = Computed(
        scope,
        function(use: Fusion.Use): Instance?
            if use<<boolean>>(props.Mixed) then return nil end

            local storedValue = use<<InstanceValue>>(props.Value)
            local usedValue: Instance? =
                if usesInstanceHandle
                then (storedValue :: InstanceHandle):Get()
                else storedValue :: Instance?

            if usedValue and InstanceHandle.IsEmptyTarget(usedValue) then
                return nil
            end

            return usedValue
        end
    )

    local trySetValue = props.TrySetValue
    local writable = props.Writable and trySetValue ~= nil

    local function TryCommitValue(nextValue: Instance?)
        local setValue = trySetValue
        if setValue == nil then return end

        local committedValue: InstanceValue =
            if usesInstanceHandle
            then if nextValue ~= nil
                then InstanceHandle.new(nextValue)
                else InstanceHandle.Empty
            else nextValue
        local success, err = setValue(committedValue)
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

    local hoverState = props.HoverState
    local clearTransparency =
        if writable and hoverState
        then CreateClearTransparency(scope, hoverState)
        else nil
    local instanceIconTransparency =
        if clearTransparency
        then Computed(
            scope,
            function(use: Fusion.Use): number
                return 1 - use<<number>>(clearTransparency)
            end
        )
        else nil
    local clearInteractable =
        if hoverState
        then Computed(
            scope,
            function(use: Fusion.Use): boolean
                return use<<boolean>>(hoverState)
            end
        )
        else nil

    local indicator = Computed(scope, function(
        use: Fusion.Use,
        indicatorScope: Fusion.Scope
    ): Fusion.Child
        local usedValue = use<<Instance?>>(value)
        if not usedValue then return {} end

        local classIcon = StudioService:GetClassIcon(usedValue.ClassName)

        if writable
            and hoverState
            and clearTransparency
            and instanceIconTransparency
            and clearInteractable
        then
            return New(indicatorScope, "Frame") {
                Size = UDim2.fromOffset(
                    InstanceIconSize,
                    InstanceIconSize
                ),
                BackgroundTransparency = 1,
                LayoutOrder = 1,

                Name = "InstanceValueIndicator",

                [Children] = {
                    if classIcon then
                        Icon(indicatorScope, {
                            Image = classIcon.Image,
                            ImageColor3 = Color3.new(1, 1, 1),
                            Size = UDim2.fromScale(1, 1),
                            ImageRectOffset = classIcon.ImageRectOffset,
                            ImageRectSize = classIcon.ImageRectSize,
                            ImageTransparency = instanceIconTransparency
                        })
                        else {},

                    IconButton(indicatorScope, {
                        Image = Assets.Cross,
                        Position = UDim2.fromScale(.5, .5),
                        AnchorPoint = Vector2.new(.5, .5),
                        ImageTransparency = clearTransparency,
                        Interactable = clearInteractable,
                        ZIndex = 4,

                        Name = "InstanceValueClearButton",

                        [OnEvent "Activated"] = function()
                            local callback = clearValue
                            if callback then callback() end
                        end
                    })
                }
            }
        end

        if classIcon then
            return Icon(indicatorScope, {
                Image = classIcon.Image,
                ImageColor3 = Color3.new(1, 1, 1),
                Size = UDim2.fromOffset(
                    InstanceIconSize,
                    InstanceIconSize
                ),
                ImageRectOffset = classIcon.ImageRectOffset,
                ImageRectSize = classIcon.ImageRectSize,
                LayoutOrder = 1
            })
        end

        return {}
    end)

    local displayText = Computed(
        scope,
        function(use: Fusion.Use): string
            if use<<boolean>>(props.Mixed) then return "" end
            local usedValue = use<<Instance?>>(value)
            return if usedValue then usedValue.Name else "Empty"
        end
    )
    local fontStyle = Computed(
        scope,
        function(use: Fusion.Use): Enum.FontStyle
            if use<<boolean>>(props.Mixed) then
                return Enum.FontStyle.Normal
            end
            return
                if use<<Instance?>>(value)
                then Enum.FontStyle.Normal
                else Enum.FontStyle.Italic
        end
    )

    local content = New(scope, "Frame") {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        ZIndex = 3,

        Name = "InstanceValueContent",

        [Children] = {
            Text(scope, {
                Text = displayText,
                Variant =
                    if props.DisplayAsWritable then "Primary"
                    else "Secondary",
                FontStyle = fontStyle,
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
