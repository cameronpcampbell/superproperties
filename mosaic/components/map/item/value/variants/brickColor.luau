--!strict

local Packages =
    script.Parent.Parent.Parent.Parent.Parent.Parent.Parent.Parent.packages
local Fusion = require(Packages.fusion)
local Computed, New, Children, Observer, OnEvent, Peek, Value =
    Fusion.Computed, Fusion.New, Fusion.Children, Fusion.Observer,
    Fusion.OnEvent, Fusion.peek, Fusion.Value

local CoreComponents =
    script.Parent.Parent.Parent.Parent.Parent.Parent.coreComponents
local CoreButton = require(CoreComponents.button)
local Placement = require(CoreComponents.placement)
local PopoverFocus = require(CoreComponents.popoverFocus)

local Components = script.Parent.Parent.Parent.Parent.Parent
local BrickColorPicker = require(Components.brickColorPicker)
local Container = require(Components.container)

local Types = require(script.Parent.types)
local ColorVariant = require(script.Parent.color)

local MenuGap = 4
local MenuPadding = 6

local function NewTextButton(
    scope: Fusion.Scope,
    props: { [any]: any }
): Fusion.Child
    return New(scope, "TextButton")(props)
end

return function(
    scope: Fusion.Scope,
    props: Types.ValueVariantProps<BrickColor>
): Fusion.Child
    local trySetValue = props.TrySetValue

    if not props.Writable or trySetValue == nil then
        return ColorVariant(scope, props :: any)
    end

    local observedSelectedBrickColor = Computed(
        scope,
        function(use: Fusion.Use): BrickColor?
            if use<<boolean>>(props.Mixed) then return nil end
            return use<<BrickColor>>(props.Value)
        end
    )
    local selectedBrickColorState = Value<<BrickColor?>>(
        scope,
        Peek<<BrickColor?>>(observedSelectedBrickColor)
    )

    local function SyncSelectedBrickColor()
        selectedBrickColorState:set(
            Peek<<BrickColor?>>(observedSelectedBrickColor)
        )
    end

    Observer(scope, observedSelectedBrickColor):onChange(
        SyncSelectedBrickColor
    )

    local hitArea: TextButton
    local pickerContainer: GuiObject
    local popoverFocus = PopoverFocus(scope, {
        GetInteractionRoots = function(): { GuiObject }
            return { hitArea, pickerContainer }
        end,
        OnFocusChanged =
            if props.OnFocusChanged == nil then nil
            else function(isFocused: boolean)
                props.OnFocusChanged(isFocused)
            end,
        Name = "BrickColorFocusTarget"
    })
    local inputFocusState = popoverFocus.State
    local visualFocusState = props.FocusState or inputFocusState
    local pickerTransitionTransparency = Value(scope, 1)

    local function CommitBrickColor(brickColor: BrickColor)
        local success, err, savedValue = trySetValue(brickColor)

        if success then
            selectedBrickColorState:set(savedValue or brickColor)
        else
            SyncSelectedBrickColor()
            warn(`SuperProperties: {err or "Could not set value."}`)
        end
    end

    pickerContainer = Placement(scope, Container, {
        Variant = "Tertiary",
        Size = UDim2.fromScale(1, 0),
        AutomaticSize = Enum.AutomaticSize.XY,
        Position = UDim2.new(1, 1, 1, MenuGap),
        AnchorPoint = Vector2.new(1, 0),
        ViewportFittingEnabled = true,
        StickToViewport = false,
        Visible = visualFocusState,
        Interactable = inputFocusState,
        OutTransitionTransparency = pickerTransitionTransparency,
        ZIndex = 4,

        Name = "BrickColorPickerContainer",

        [Children] = {
            BrickColorPicker(scope, {
                SelectedBrickColor = selectedBrickColorState,
                OnSelected = CommitBrickColor,
                Transparency = pickerTransitionTransparency
            }),

            New(scope, "UIPadding") {
                PaddingTop = UDim.new(0, MenuPadding),
                PaddingBottom = UDim.new(0, MenuPadding),
                PaddingLeft = UDim.new(0, MenuPadding),
                PaddingRight = UDim.new(0, MenuPadding)
            },

            New(scope, "UIListLayout") {
                FillDirection = Enum.FillDirection.Horizontal,
                HorizontalAlignment = Enum.HorizontalAlignment.Center,
            }
        }
    }) :: GuiObject

    hitArea = CoreButton(scope, NewTextButton, {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        Selectable = false,
        ZIndex = 3,

        Name = "BrickColorHitArea",

        [OnEvent "Activated"] = function()
            if Peek<<boolean>>(inputFocusState) then
                popoverFocus.Release()
            else
                popoverFocus.Capture()
            end
        end
    }) :: TextButton

    local displayedContent = New(scope, "Frame") {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        ZIndex = 1,

        Name = "BrickColorContent",

        [Children] = ({
            ColorVariant(scope, {
                Value = props.Value :: any,
                Mixed = props.Mixed,
                TextColor3 = props.TextColor3,
                Writable = false
            }),

            New(scope, "UIListLayout") {
                Padding = UDim.new(0, 6),
                FillDirection = Enum.FillDirection.Horizontal,
                VerticalAlignment = Enum.VerticalAlignment.Center,
                SortOrder = Enum.SortOrder.LayoutOrder
            }
        } :: { Fusion.Child })
    }

    return New(scope, "Frame") {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,

        Name = "BrickColorValue",

        [Children] = ({
            displayedContent,
            popoverFocus.Target,
            hitArea,
            pickerContainer,

            New(scope, "UIFlexItem") {
                FlexMode = Enum.UIFlexMode.Shrink
            }
        } :: { Fusion.Child })
    }
end
