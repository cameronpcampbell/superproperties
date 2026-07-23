--!strict

local Packages = script.Parent.Parent.Parent
local Fusion = require(Packages.fusion)
local New, OnEvent, Peek, Value =
    Fusion.New, Fusion.OnEvent, Fusion.peek, Fusion.Value

export type Props = {
    GetInteractionRoots: () -> { GuiObject },
    OnFocusChanged: ((boolean, InputObject?) -> ())?,
    Name: string?
}

export type Controller = {
    State: Fusion.Value<boolean>,
    Target: TextBox,
    Capture: () -> (),
    Release: () -> (),
    CaptureChild: (TextBox) -> (),
    ChildFocused: (TextBox?) -> (),
    ChildFocusLost: (InputObject?) -> ()
}

local function IsPointInside(guiObject: GuiObject, point: Vector3): boolean
    local topLeft = guiObject.AbsolutePosition
    local bottomRight = topLeft + guiObject.AbsoluteSize

    return point.X >= topLeft.X
        and point.X <= bottomRight.X
        and point.Y >= topLeft.Y
        and point.Y <= bottomRight.Y
end

return function(scope: Fusion.Scope, props: Props): Controller
    local focusState = Value(scope, false)
    local scopeAlive = true
    local childFocusTarget: TextBox? = nil
    local isChildFocused = false
    local childFocusTransferPending = false
    local focusTarget: TextBox
    local focusRevision = 0

    table.insert(scope, function()
        scopeAlive = false
    end)

    local function setFocused(
        isFocused: boolean,
        inputThatCausedFocusLoss: InputObject?
    )
        if Peek<<boolean>>(focusState) == isFocused then return end

        focusState:set(isFocused)
        if props.OnFocusChanged then
            props.OnFocusChanged(isFocused, inputThatCausedFocusLoss)
        end
    end

    local function cancelPendingFocusLoss()
        focusRevision += 1
    end

    local function deferFocusLoss(
        inputThatCausedFocusLoss: InputObject?
    )
        focusRevision += 1
        local revision = focusRevision

        task.defer(function()
            if not scopeAlive then return end
            if revision ~= focusRevision then return end
            if not Peek<<boolean>>(focusState) then return end
            if childFocusTransferPending or isChildFocused then return end
            if focusTarget:IsFocused() then return end

            setFocused(false, inputThatCausedFocusLoss)
        end)
    end

    local function captureTargetDeferred()
        task.defer(function()
            if not scopeAlive then return end
            if not Peek<<boolean>>(focusState) then return end
            if isChildFocused or focusTarget:IsFocused() then return end

            focusTarget:CaptureFocus()
        end)
    end

    local function handleFocusLost(
        inputThatCausedFocusLoss: InputObject?
    )
        if childFocusTransferPending then return end

        if inputThatCausedFocusLoss ~= nil then
            for _, root in props.GetInteractionRoots() do
                if IsPointInside(root, inputThatCausedFocusLoss.Position) then
                    -- Gui clicks release TextBox focus before Activated fires.
                    -- Restore the hidden target after that click has a chance to
                    -- focus a child or close the popover.
                    cancelPendingFocusLoss()
                    captureTargetDeferred()
                    return
                end
            end
        end

        -- Roblox can omit the causal InputObject while transferring focus
        -- between TextBoxes. Give the next child one task tick to claim focus
        -- before treating this as an outside dismissal.
        deferFocusLoss(inputThatCausedFocusLoss)
    end

    focusTarget = New(scope, "TextBox") {
        Size = UDim2.fromOffset(0, 0),
        Position = UDim2.fromOffset(-1, -1),
        BackgroundTransparency = 1,
        Text = "",
        TextTransparency = 1,
        TextEditable = false,
        ClearTextOnFocus = false,
        Selectable = false,

        Name = props.Name or "PopoverFocusTarget",

        [OnEvent "Focused"] = function()
            cancelPendingFocusLoss()
            setFocused(true, nil)
        end,

        [OnEvent "FocusLost"] = function(
            _enterPressed: boolean,
            inputThatCausedFocusLoss: InputObject?
        )
            handleFocusLost(inputThatCausedFocusLoss)
        end
    } :: TextBox

    local function capture()
        cancelPendingFocusLoss()
        childFocusTransferPending = false
        isChildFocused = false

        if not focusTarget:IsFocused() then focusTarget:CaptureFocus() end
        setFocused(true, nil)
    end

    local function release()
        cancelPendingFocusLoss()
        childFocusTransferPending = false
        isChildFocused = false
        setFocused(false, nil)

        local child = childFocusTarget
        if child and child:IsFocused() then child:ReleaseFocus(false) end
        if focusTarget:IsFocused() then focusTarget:ReleaseFocus(false) end
    end

    local function captureChild(child: TextBox)
        cancelPendingFocusLoss()
        childFocusTarget = child
        isChildFocused = false
        setFocused(true, nil)

        if child:IsFocused() then
            childFocusTransferPending = false
            isChildFocused = true
            return
        end

        childFocusTransferPending = true
        child:CaptureFocus()

        task.defer(function()
            if not scopeAlive then return end
            if childFocusTarget ~= child then return end
            if not childFocusTransferPending then return end

            childFocusTransferPending = false
            isChildFocused = child:IsFocused()

            if not isChildFocused then captureTargetDeferred() end
        end)
    end

    local function childFocused(child: TextBox?)
        cancelPendingFocusLoss()
        if child then childFocusTarget = child end
        childFocusTransferPending = false
        isChildFocused = true
        setFocused(true, nil)
    end

    local function childFocusLost(
        inputThatCausedFocusLoss: InputObject?
    )
        childFocusTransferPending = false
        isChildFocused = false
        handleFocusLost(inputThatCausedFocusLoss)
    end

    return {
        State = focusState,
        Target = focusTarget,
        Capture = capture,
        Release = release,
        CaptureChild = captureChild,
        ChildFocused = childFocused,
        ChildFocusLost = childFocusLost
    }
end
