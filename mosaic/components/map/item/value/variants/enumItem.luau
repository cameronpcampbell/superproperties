--!strict

local CreateSelectMenuVariant =
    require(script.Parent.utils.createSelectMenuVariant)

type EnumMetadata = {
    Items: { EnumItem },
    Names: { string },
    IndexByItem: { [EnumItem]: number }
}

local EnumMetadataByType: { [any]: EnumMetadata } = {}

local function GetEnumMetadata(value: EnumItem): EnumMetadata
    local enumType = value.EnumType
    local metadata = EnumMetadataByType[enumType]
    if metadata then return metadata end

    local items = enumType:GetEnumItems()
    local names = table.create(#items) :: { string }
    local indexByItem = {} :: { [EnumItem]: number }

    for idx, item in items do
        names[idx] = item.Name
        indexByItem[item] = idx
    end

    local createdMetadata: EnumMetadata = {
        Items = table.freeze(items),
        Names = table.freeze(names),
        IndexByItem = table.freeze(indexByItem)
    }
    EnumMetadataByType[enumType] = createdMetadata
    return createdMetadata
end

return CreateSelectMenuVariant<<EnumItem>>({
    Name = "EnumItem",

    GetMetadata = function(initialValue: EnumItem)
        local metadata = GetEnumMetadata(initialValue)

        return {
            Items = metadata.Names :: any,

            GetIndex = function(value: EnumItem): number?
                return metadata.IndexByItem[value]
            end,

            ResolveValue = function(
                idx: number,
                _currentValue: EnumItem
            ): EnumItem?
                return metadata.Items[idx]
            end
        }
    end,

    Format = function(value: EnumItem): string
        return value.Name
    end
})
