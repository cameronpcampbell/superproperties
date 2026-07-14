--!strict

local Utils = script.Parent.Parent.Parent.utils
local ThemeUtils = require(Utils.themeUtils)

export type BaseMapProps = {
    Variant: ThemeUtils.BgVariantLayer,
    RowCount: number,
    RowIdx: number
}

export type Item = {
    Key: string,
    Value: any,
    SubItems: { Item }?
}

export type Items = { Item }

return nil
