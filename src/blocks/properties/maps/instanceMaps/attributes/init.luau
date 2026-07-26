--!strict

local Packages = script.Parent.Parent.Parent.Parent.Parent.packages

local Fusion = require(Packages.fusion)
local Children, Computed, New, OnEvent, Peek, Value =
    Fusion.Children, Fusion.Computed, Fusion.New, Fusion.OnEvent, Fusion.peek,
    Fusion.Value

local Mosaic = require(Packages.mosaic)
local Button, Container, IconButton, Input, Placement, PopoverFocus, Select =
    Mosaic.Button, Mosaic.Container, Mosaic.IconButton, Mosaic.Input,
    Mosaic.Placement, Mosaic.PopoverFocus, Mosaic.Select

local Map = require(Packages.mosaic.components.map)
type Item = Map.Item
type TransformValue = Map.TransformValue

local InstanceHandle = require(
    Packages.mosaic.components.map.item.value.variants["instanceHandle.types"]
)

local Assets = require(script.Parent.Parent.Parent.Parent.Parent.assets)

local Category = require(script.Parent.Parent.category)
type CategoryState = Category.State

local CommitAttribute = require(script.commitAttribute)
local CommitRenameAttribute = require(script.commitRenameAttribute)

type AttributesMapProps = {
    OmitRbxAttributes: boolean
}

type AttributeTypeOption = {
    Label: string,
    DefaultValue: any
}

type AttributeTarget = {
    Instance: Instance,
    Value: any
}

type AttributeGroup = {
    Name: string,
    ValueType: string,
    CompatibleTypes: boolean,
    Targets: { AttributeTarget }
}

local RBX_ATTRIBUTE_PREFIX = "RBX_"
local MENU_OFFSET = 4
local MENU_GAP = 6
local MENU_PADDING = 7
local MENU_RIGHT_INSET = 6

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
    { Label = "Font", DefaultValue = Font.fromEnum(Enum.Font.SourceSans) },
    {
        Label = "Instance",
        DefaultValue = InstanceHandle.Empty
    }
}
local AttributeTypeLabels = table.create(#AttributeTypes) :: { string }

for idx, option in AttributeTypes do
    AttributeTypeLabels[idx] = option.Label
end

local function Trim(text: string): string
    return text:match("^%s*(.-)%s*$") or ""
end

local function ShouldOmitAttribute(
    attributeName: string,
    omitRbxAttributes: boolean
): boolean
    return omitRbxAttributes
        and string.sub(attributeName, 1, #RBX_ATTRIBUTE_PREFIX)
            == RBX_ATTRIBUTE_PREFIX
end

return function(
    scope: Fusion.Scope,
    outerScope: Fusion.Scope,
    collapsedStateScope: Fusion.Scope,
    instances: { Instance },
    props: AttributesMapProps
): CategoryState
    local attributeItemsState = Value<<{ Item }>>(scope, {})
    local groupsByName: { [string]: AttributeGroup } = {}
    local itemChildrenScope = Fusion.innerScope(scope)
    local refreshItems: () -> ()

    local function getTargetInstances(
        group: AttributeGroup
    ): { Instance }
        local targetInstances =
            table.create(#group.Targets) :: { Instance }
        for targetIdx, target in group.Targets do
            targetInstances[targetIdx] = target.Instance
        end
        return targetInstances
    end

    local function commitGroupTransform(
        group: AttributeGroup,
        transformValue: TransformValue
    ): (boolean, string?, any?)
        local success, err = CommitAttribute(
            getTargetInstances(group),
            group.Name,
            transformValue
        )
        refreshItems()

        local savedValue = group.Targets[1].Instance:GetAttribute(group.Name)
        return success, err, if success then savedValue else nil
    end

    local function removeAttribute(group: AttributeGroup)
        local success, err = CommitAttribute(
            getTargetInstances(group),
            group.Name,
            function(): any? return nil end
        )
        refreshItems()

        if not success then
            warn(`Could not remove attribute {group.Name}: {err}`)
        end
    end

    local function renameAttribute(
        group: AttributeGroup,
        requestedName: string
    ): (boolean, string?, string?)
        local newAttributeName = Trim(requestedName)

        if newAttributeName == group.Name then
            return true, nil, group.Name
        end
        if newAttributeName == "" then
            return false, "Attribute name cannot be empty.", nil
        end
        if ShouldOmitAttribute(
            newAttributeName,
            props.OmitRbxAttributes
        ) then
            return false,
                `Attribute names beginning with {RBX_ATTRIBUTE_PREFIX} are hidden.`,
                nil
        end
        if groupsByName[newAttributeName] ~= nil then
            return false,
                `Attribute {newAttributeName} already exists.`,
                nil
        end

        local success, err = CommitRenameAttribute(
            getTargetInstances(group),
            group.Name,
            newAttributeName
        )
        refreshItems()

        return success, err, if success then newAttributeName else nil
    end

    refreshItems = function()
        Fusion.doCleanup(itemChildrenScope)
        itemChildrenScope = Fusion.innerScope(scope)

        local nextGroupsByName: { [string]: AttributeGroup } = {}
        for _, instance in instances do
            for attributeName, attributeValue in instance:GetAttributes() do
                if ShouldOmitAttribute(
                    attributeName,
                    props.OmitRbxAttributes
                ) then
                    continue
                end

                local group = nextGroupsByName[attributeName]
                if not group then
                    group = {
                        Name = attributeName,
                        ValueType = typeof(attributeValue),
                        CompatibleTypes = true,
                        Targets = {}
                    }
                    nextGroupsByName[attributeName] = group
                elseif typeof(attributeValue) ~= group.ValueType then
                    group.CompatibleTypes = false
                end

                table.insert(group.Targets, {
                    Instance = instance,
                    Value = attributeValue
                })
            end
        end

        groupsByName = nextGroupsByName
        local attributeItems = {} :: { Item }

        for _, group in groupsByName do
            local comparisonValues =
                table.create(#group.Targets) :: { Fusion.UsedAs<any?> }
            for targetIdx, target in group.Targets do
                comparisonValues[targetIdx] = target.Value
            end

            local item: Item = {
                Key = group.Name,
                KeyWritable = true,
                TrySetKey = function(
                    requestedName: string
                ): (boolean, string?, string?)
                    return renameAttribute(group, requestedName)
                end,
                Value = group.Targets[1].Value,
                ComparisonValues = comparisonValues,
                ValueType =
                    if group.CompatibleTypes then group.ValueType
                    else "MixedAttributeTypes",
                ValueWritable = group.CompatibleTypes
            }
            if group.CompatibleTypes then
                item.TrySetValue = function(
                    value: any
                ): (boolean, string?, any?)
                    return commitGroupTransform(
                        group,
                        function(): any return value end
                    )
                end
                item.TryTransformValue = function(
                    transformValue: TransformValue
                ): (boolean, string?, any?)
                    return commitGroupTransform(group, transformValue)
                end
            end
            item.KeyChildren = {
                IconButton(itemChildrenScope, {
                    Image = Assets.Cross,

                    [OnEvent "MouseButton1Click"] = function()
                        removeAttribute(group)
                    end
                })
            }
            table.insert(attributeItems, item)
        end

        attributeItemsState:set(attributeItems)
    end

    refreshItems()

    local refreshPending = false
    local alive = true
    local function queueRefresh()
        if refreshPending then return end
        refreshPending = true

        task.defer(function()
            refreshPending = false
            if alive then refreshItems() end
        end)
    end

    table.insert(scope, function() alive = false end)
    for _, instance in instances do
        table.insert(
            scope,
            instance.AttributeChanged:Connect(function(
                _attributeName: string
            )
                queueRefresh()
            end)
        )
    end

    local nameState = Value<<string?>>(scope, "")
    local selectedTypeIdxState = Value<<number?>>(scope, 1)
    local attributeMenu: GuiObject
    local addButton: GuiObject

    local function resetCreateAttributeForm()
        nameState:set("")
        selectedTypeIdxState:set(1)
    end

    local popoverFocus = PopoverFocus(scope, {
        GetInteractionRoots = function(): { GuiObject }
            return { attributeMenu, addButton }
        end,
        Name = "AttributesMenuFocusTarget"
    })
    local createAttributeDisabled = Computed(scope, function(use): boolean
        return
            not use<<boolean>>(popoverFocus.State)
            or Trim(use<<string?>>(nameState) or "") == ""
    end)

    local function createAttribute()
        local attributeName = Trim(Peek<<string?>>(nameState) or "")
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
        if groupsByName[attributeName] ~= nil then
            warn(`SuperProperties: Attribute {attributeName} already exists.`)
            return
        end

        local selectedTypeIdx = Peek<<number?>>(selectedTypeIdxState)
        local attributeType =
            if selectedTypeIdx == nil then nil
            else AttributeTypes[selectedTypeIdx]
        if attributeType == nil then
            warn("SuperProperties: Select an attribute type.")
            return
        end

        local success, err = CommitAttribute(
            instances,
            attributeName,
            function(): any return attributeType.DefaultValue end
        )
        refreshItems()
        if not success then
            warn(`Could not create attribute {attributeName}: {err}`)
            return
        end

        resetCreateAttributeForm()
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
            Input(scope, {
                Variant = "Quaternary",
                Text = nameState,
                PlaceholderText = "Name",
                ParentPopoverFocus = popoverFocus,
                Interactable = popoverFocus.State,
                LayoutOrder = 1
            }),

            Select(scope, {
                Variant = "Quaternary",
                Items = AttributeTypeLabels,
                SelectedIdx = selectedTypeIdxState,
                ParentPopoverFocus = popoverFocus,
                Interactable = popoverFocus.State,
                LayoutOrder = 2
            }),

            Button(scope, {
                LayoutOrder = 3,
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

    return Category(scope, outerScope, collapsedStateScope, {
        Name = "Attributes",
        HeaderChildren = function(
            headerScope: Fusion.Scope,
            headerColors: Map.HeaderColors
        ): { Fusion.Child }
            addButton = IconButton(headerScope, {
                Image = Assets.Add,
                ImageColor3 = headerColors.ForegroundColor3,

                [OnEvent "MouseButton1Click"] = function()
                    if Peek<<boolean>>(popoverFocus.State) then
                        popoverFocus.Release()
                        return
                    end

                    resetCreateAttributeForm()
                    popoverFocus.Capture()
                end
            }) :: GuiObject

            return { addButton }
        end,
        HeaderOverlay = ({
            attributeMenu,
            popoverFocus.Target
        } :: any),
        ShowOnTop = popoverFocus.State,
        Items = attributeItemsState,
        EmptyText = "No Attributes have been added yet."
    })
end
