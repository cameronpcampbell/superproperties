--!strict

local CreateSelectMenuVariant =
    require(script.Parent.utils.createSelectMenuVariant)

local FontItems = {} :: { Enum.Font }
local MenuItems = {}
local IndexByFamily = {} :: { [string]: number }
local NameByFamily = {} :: { [string]: string }

for _, enumFont in Enum.Font:GetEnumItems() do
    if enumFont == Enum.Font.Unknown then continue end

    local font = Font.fromEnum(enumFont)
    local family = font.Family
    if IndexByFamily[family] ~= nil then continue end

    local idx = #FontItems + 1
    FontItems[idx] = enumFont
    MenuItems[idx] = {
        Text = enumFont.Name,
        FontFace = font
    }
    IndexByFamily[family] = idx
    NameByFamily[family] = enumFont.Name
end

table.freeze(FontItems)
table.freeze(MenuItems)
table.freeze(IndexByFamily)
table.freeze(NameByFamily)

local function GetFamilyName(font: Font): string
    return NameByFamily[font.Family] or font.Family
end

return CreateSelectMenuVariant({
    Name = "Font",
    EnableSearch = false,
    SortOrder = Enum.SortOrder.Name,

    GetMetadata = function(_initialValue: Font)
        return {
            Items = MenuItems,

            GetIndex = function(value: Font): number?
                return IndexByFamily[value.Family]
            end,

            ResolveValue = function(
                idx: number,
                currentValue: Font
            ): Font?
                local enumFont = FontItems[idx]
                if enumFont == nil then return nil end

                local selectedFont = Font.fromEnum(enumFont)
                return Font.new(
                    selectedFont.Family,
                    currentValue.Weight,
                    currentValue.Style
                )
            end
        }
    end,

    Format = GetFamilyName,
    GetDisplayFontFace = function(value: Font): Font
        return value
    end
})
