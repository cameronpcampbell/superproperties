--!strict

local Packages = script.Parent.Parent.Parent.Parent.Parent.packages

local Fusion = require(Packages.fusion)
local Children, Computed, New, OnEvent, Peek, Value =
    Fusion.Children, Fusion.Computed, Fusion.New, Fusion.OnEvent, Fusion.peek,
    Fusion.Value

local Mosaic = require(Packages.mosaic)
local Button, Container, IconButton, Input, Placement, PopoverFocus, Select,
    Text =
    Mosaic.Button, Mosaic.Container, Mosaic.IconButton, Mosaic.Input,
    Mosaic.Placement, Mosaic.PopoverFocus, Mosaic.Select, Mosaic.Text

local Map = require(Packages.mosaic.components.map)
type Item = Map.Item

local Assets = require(script.Parent.Parent.Parent.Parent.Parent.assets)

local Category = require(script.Parent.Parent.category)
type CategoryState = Category.State

local CommitAttribute = require(script.Parent.commitAttribute)

type AttributesMapProps = {
    OmitRbxAttributes: boolean
}

type AttributeTypeOption = {
    Label: string,
    DefaultValue: any
}

local RBX_ATTRIBUTE_PREFIX = "RBX_"
local MENU_OFFSET = 4
local MENU_GAP = 6
local MENU_PADDING = 7
local MENU_RIGHT_INSET = 6
local CAPTION_LEFT_PADDING = 7

local AttributeTypes: { AttributeTypeOption } = {
    { Label = "string", DefaultValue = "" },
    { Label = "boolean", DefaultValue = false },
    { Label = "number", DefaultValue = 0 },
    { Label = "UDim", DefaultValue = UDim.new() },
    { Label = "UDim2", DefaultValue = UDim2.new() },
    { Label = "BrickColor", DefaultValue = BrickColor.new() },
    { Label = "Color3", DefaultValue = Color3.new() },
    { Label = "Vector2", DefaultValue = Vector2.new() },
    { Label = "Vector3", DefaultValue = Vector3.new() },
    { Label = "CFrame", DefaultValue = CFrame.new() },
    { Label = "NumberSequence", DefaultValue = NumberSequence.new(0) },
    { Label = "ColorSequence", DefaultValue = ColorSequence.new(Color3.new()) },
    { Label = "NumberRange", DefaultValue = NumberRange.new(0) },
    { Label = "Rect", DefaultValue = Rect.new() },
    { Label = "Font", DefaultValue = Font.fromEnum(Enum.Font.SourceSans) }
}
local AttributeTypeLabels = table.create(#AttributeTypes) :: { string }

for idx, option in AttributeTypes do
    AttributeTypeLabels[idx] = option.Label
end

local function Trim(text: string): string
    return text:match("^%s*(.-)%s*$") or ""
end

local function CreateCaption(
    scope: Fusion.Scope,
    caption: string,
    layoutOrder: number
): Fusion.Child
    return New(scope, "Frame") {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        LayoutOrder = layoutOrder,

        [Children] = {
            Text(scope, {
                Text = caption,
                Variant = "Secondary",
                FontSize = "Caption",
                Size = UDim2.new(1, 0, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y
            }),

            New(scope, "UIPadding") {
                PaddingLeft = UDim.new(0, CAPTION_LEFT_PADDING)
            }
        }
    }
end

local function GetAttributeName(item: Item): string
    local attributeName = item.Key
    assert(attributeName ~= nil, "Attribute map items must have keys.")
    return attributeName
end

local function ShouldOmitAttribute(
    attributeName: string,
    omitRbxAttributes: boolean
): boolean
    return omitRbxAttributes
        and string.sub(attributeName, 1, #RBX_ATTRIBUTE_PREFIX)
            == RBX_ATTRIBUTE_PREFIX
end

local function GetAttributeItems(
    instance: Instance,
    omitRbxAttributes: boolean
): { Item }
    local attributes = instance:GetAttributes()
    local attributeItems = {} :: { Item }

    local attributeIdx = 1
    for attributeName, attributeValue in attributes do
        if ShouldOmitAttribute(attributeName, omitRbxAttributes) then
            continue
        end

        attributeItems[attributeIdx] = {
            Key = attributeName,
            Value = attributeValue
        }

        attributeIdx += 1
    end

    return attributeItems
end

return function(
    scope: Fusion.Scope,
    outerScope: Fusion.Scope,
    collapsedStateScope: Fusion.Scope,
    instance: Instance,
    props: AttributesMapProps
): CategoryState
    local attributeItems = GetAttributeItems(
        instance,
        props.OmitRbxAttributes
    )
    local attributeItemIndices: { [string]: number } = {}
    local attributeItemsState = Value(scope, attributeItems)

    for itemIdx, item in attributeItems do
        attributeItemIndices[GetAttributeName(item)] = itemIdx
    end

    local refreshAttribute: (attributeName: string) -> (boolean, any?)

    local function removeAttribute(attributeName: string)
        local success, err = CommitAttribute(
            instance,
            attributeName,
            nil
        )
        if not success then
            warn(`Could not remove attribute {attributeName}: {err}`)
            return
        end

        refreshAttribute(attributeName)
    end

    local function makeAttributeWritable(item: Item, attributeName: string)
        item.Writable = true
        item.ValueChildren = {
            IconButton(scope, {
                Image = Assets.Cross,

                [OnEvent "MouseButton1Click"] = function()
                    removeAttribute(attributeName)
                end
            })
        }
        item.TrySetValue = function(value: any): (boolean, string?, any?)
            if item.Value == value then return true, nil, item.Value end

            local success, err = CommitAttribute(
                instance,
                attributeName,
                value
            )

            local _, savedValue = refreshAttribute(attributeName)
            return success, err, if success then savedValue else nil
        end
    end

    refreshAttribute = function(attributeName: string): (boolean, any?)
        if ShouldOmitAttribute(
            attributeName,
            props.OmitRbxAttributes
        ) then
            return false, nil
        end

        local itemIdx = attributeItemIndices[attributeName]
        local value = instance:GetAttribute(attributeName)

        if value == nil then
            if not itemIdx then return false, nil end

            table.remove(attributeItems, itemIdx)
            attributeItemIndices[attributeName] = nil

            for shiftedIdx = itemIdx, #attributeItems do
                local shiftedItem = attributeItems[shiftedIdx]
                attributeItemIndices[GetAttributeName(shiftedItem)] = shiftedIdx
            end
        elseif itemIdx then
            local item = attributeItems[itemIdx]
            if item.Value == value then return false, value end

            item.Value = value
        else
            local item: Item = {
                Key = attributeName,
                Value = value
            }
            makeAttributeWritable(item, attributeName)
            table.insert(attributeItems, item)
            attributeItemIndices[attributeName] = #attributeItems
        end

        attributeItemsState:set(attributeItems)
        return true, value
    end

    for _, item in attributeItems do
        makeAttributeWritable(item, GetAttributeName(item))
    end

    table.insert(
        scope,
        instance.AttributeChanged:Connect(refreshAttribute)
    )

    local nameState = Value(scope, "")
    local createAttributeDisabled = Computed(scope, function(use): boolean
        return Trim(use<<string>>(nameState)) == ""
    end)
    local selectedTypeIdxState = Value<<number?>>(scope, 1)
    local attributeMenu: GuiObject
    local addButton: GuiObject
    local popoverFocus = PopoverFocus(scope, {
        GetInteractionRoots = function(): { GuiObject }
            return { attributeMenu, addButton }
        end,
        Name = "AttributesMenuFocusTarget"
    })

    local function createAttribute()
        local attributeName = Trim(Peek<<string>>(nameState))
        if attributeName == "" then
            warn("SuperProperties: Attribute name cannot be empty.")
            return
        end

        if ShouldOmitAttribute(attributeName, props.OmitRbxAttributes) then
            warn(
                `SuperProperties: Attribute names beginning with {RBX_ATTRIBUTE_PREFIX} are hidden.`
            )
            return
        end

        if instance:GetAttribute(attributeName) ~= nil then
            warn(
                `SuperProperties: Attribute {attributeName} already exists.`
            )
            return
        end

        local selectedTypeIdx =
            Peek<<number?>>(selectedTypeIdxState)
        local attributeType =
            if selectedTypeIdx == nil then nil
            else AttributeTypes[selectedTypeIdx]
        if attributeType == nil then
            warn("SuperProperties: Select an attribute type.")
            return
        end

        local success, err = CommitAttribute(
            instance,
            attributeName,
            attributeType.DefaultValue
        )
        if not success then
            warn(`Could not create attribute {attributeName}: {err}`)
            return
        end

        refreshAttribute(attributeName)
        popoverFocus.Release()
    end

    attributeMenu = Placement(scope, Container, {
        Variant = "Tertiary",
        Size = UDim2.new(.5, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Position = UDim2.new(1, -MENU_RIGHT_INSET, 1, MENU_OFFSET),
        AnchorPoint = Vector2.new(1, 0),
        Enabled = popoverFocus.State,
        Visible = popoverFocus.State,
        ZIndex = 4,
        ContentZIndex = 4,

        Name = "CreateAttributeMenu",

        [Children] = {
            CreateCaption(scope, "Name", 1),

            Input(scope, {
                Variant = "Quaternary",
                Text = nameState,
                PlaceholderText = "Enter a name...",
                ParentPopoverFocus = popoverFocus,
                LayoutOrder = 2
            }),

            CreateCaption(scope, "Type", 3),

            Select(scope, {
                Variant = "Quaternary",
                Items = AttributeTypeLabels,
                SelectedIdx = selectedTypeIdxState,
                ParentPopoverFocus = popoverFocus,
                LayoutOrder = 4
            }),

            Button(scope, {
                LayoutOrder = 5,
                Disabled = createAttributeDisabled,

                [OnEvent "MouseButton1Click"] = createAttribute,
                [Children] = "Create"
            }),

            New(scope, "UIListLayout") {
                FillDirection = Enum.FillDirection.Vertical,
                SortOrder = Enum.SortOrder.LayoutOrder,
                Padding = UDim.new(0, MENU_GAP)
            },

            New(scope, "UIPadding") {
                PaddingLeft = UDim.new(0, MENU_PADDING),
                PaddingRight = UDim.new(0, MENU_PADDING),
                PaddingTop = UDim.new(0, MENU_PADDING),
                PaddingBottom = UDim.new(0, MENU_PADDING)
            }
        }
    }) :: GuiObject

    addButton = IconButton(scope, {
        Image = Assets.Add,

        [OnEvent "MouseButton1Click"] = function()
            if Peek<<boolean>>(popoverFocus.State) then
                popoverFocus.Release()
                return
            end

            nameState:set("")
            selectedTypeIdxState:set(1)
            popoverFocus.Capture()
        end
    }) :: GuiObject

    return Category(scope, outerScope, collapsedStateScope, {
        Name = "Attributes",
        HeaderChildren = ({
            addButton
        } :: { Fusion.Child }),
        HeaderOverlay = ({
            attributeMenu,
            popoverFocus.Target
        } :: Fusion.Child),
        ShowOnTop = popoverFocus.State,
        Items = attributeItemsState,
        EmptyText = "No Attributes have been added yet."
    })
end
