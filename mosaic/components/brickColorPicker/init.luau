--!strict
--!nolint LocalShadow

local Packages = script.Parent.Parent.Parent

local Fusion = require(Packages.fusion)
local New, Children, Computed, Value =
    Fusion.New, Fusion.Children, Fusion.Computed, Fusion.Value

local Utils = script.Parent.Parent.utils

local FusionUtils = require(Utils.fusionUtils)
local Component, CombineProps =
    FusionUtils.Component, FusionUtils.CombineProps

local TableUtils = require(Utils.tableUtils)
local TableExtract = TableUtils.Extract

local BrickColorItem = require(script.item)

local CellWidth = 20
local CellHeight = 23
local MaximumColumns = 13

local PaletteRowSizes = {
    7, 8, 9, 10, 11, 12, 13,
    12, 11, 10, 9, 8, 7
}

local HexRowStep = CellHeight * 3 / 4
local HexRowPadding = HexRowStep - CellHeight

local BottomRowBrickColorNames = {
    "Dark stone grey",
    "Medium stone grey",
    "Mid gray",
    "Lily white",
    "White",
    "Black",
    "Smoky grey",
    "Fossil",
    "Ghost grey",
    "Fog",
    "Institutional white"
}

local BottomRowSize = #BottomRowBrickColorNames + 1

type ColorSelectedCallback = (color: Color3) -> ()

local function CreatePaletteRow(
    scope: Fusion.Scope,
    brickColors: { BrickColor },
    firstPaletteIndex: number,
    rowIndex: number,
    padding: number,
    maximumRowWidth: number,
    selectedColor: Fusion.UsedAs<Color3?>,
    onSelected: ColorSelectedCallback
): Fusion.Child
    local rowChildren = {} :: { Fusion.Child }

    for columnIndex, brickColor in brickColors do
        table.insert(rowChildren, BrickColorItem(scope, {
            BrickColor = brickColor,
            PaletteIndex = firstPaletteIndex + columnIndex - 1,
            Size = UDim2.fromOffset(CellWidth, CellHeight),
            SelectedColor = selectedColor,
            OnSelected = onSelected
        }))
    end

    table.insert(rowChildren, New(scope, "UIListLayout") {
        FillDirection = Enum.FillDirection.Horizontal,
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, padding)
    })

    return New(scope, "Frame") {
        Size = UDim2.fromOffset(maximumRowWidth, CellHeight),
        BackgroundTransparency = 1,
        LayoutOrder = rowIndex,

        [Children] = rowChildren,

        Name = `PaletteRow{rowIndex}`
    }
end

local function CreatePaletteChildren(
    scope: Fusion.Scope,
    padding: number,
    rowPadding: number,
    maximumRowWidth: number,
    selectedColor: Fusion.UsedAs<Color3?>,
    onSelected: ColorSelectedCallback
): { Fusion.Child }
    local paletteRows = {} :: { Fusion.Child }
    local paletteIndex = 0

    for rowIndex, rowSize in PaletteRowSizes do
        local rowColors = table.create(rowSize) :: { BrickColor }
        local firstPaletteIndex = paletteIndex

        for columnIndex = 1, rowSize do
            rowColors[columnIndex] = BrickColor.palette(paletteIndex)
            paletteIndex += 1
        end

        table.insert(paletteRows, CreatePaletteRow(
            scope,
            rowColors,
            firstPaletteIndex,
            rowIndex,
            padding,
            maximumRowWidth,
            selectedColor,
            onSelected
        ))
    end

    local bottomRowColors = table.create(BottomRowSize) :: { BrickColor }
    bottomRowColors[1] = BrickColor.palette(paletteIndex)

    for index, brickColorName in BottomRowBrickColorNames do
        bottomRowColors[index + 1] =
            (BrickColor.new :: (string) -> BrickColor)(brickColorName)
    end

    table.insert(paletteRows, CreatePaletteRow(
        scope,
        bottomRowColors,
        paletteIndex,
        #PaletteRowSizes + 1,
        padding,
        maximumRowWidth,
        selectedColor,
        onSelected
    ))

    table.insert(paletteRows, New(scope, "UIListLayout") {
        FillDirection = Enum.FillDirection.Vertical,
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, rowPadding)
    })

    return paletteRows
end

type BrickColorPickerProps = {
    Padding: number?,
    ColorState: Fusion.Value<Color3>?
}

return Component<<BrickColorPickerProps>>(function(scope, props)
    local props, extractedColorState =
        TableExtract(props, "ColorState")
    local providedColorState =
        extractedColorState :: Fusion.Value<Color3>?
    local props, padding = TableExtract(props, "Padding", 1)
    padding = math.max(0, padding)

    local internalColorState = Value<<Color3?>>(scope, nil)
    local selectedColor = Computed(scope, function(use): Color3?
        local colorState = providedColorState

        return
            if colorState then use<<Color3>>(colorState)
            else use<<Color3?>>(internalColorState)
    end)

    local function SetSelectedColor(color: Color3)
        local colorState = providedColorState

        if colorState then
            colorState:set(color)
        else
            internalColorState:set(color)
        end
    end

    local maximumRowWidth =
        MaximumColumns * CellWidth
        + (MaximumColumns - 1) * padding
    local rowCount = #PaletteRowSizes + 1
    local rowPadding = HexRowPadding + padding
    local paletteHeight =
        rowCount * CellHeight
        + (rowCount - 1) * rowPadding

    return New(scope, "Frame")(CombineProps({
        Size = UDim2.fromOffset(maximumRowWidth, paletteHeight),
        BackgroundTransparency = 1,

        [Children] = CreatePaletteChildren(
            scope,
            padding,
            rowPadding,
            maximumRowWidth,
            selectedColor,
            SetSelectedColor
        ),

        Name = "BrickColorPicker"
    }, props))
end)
