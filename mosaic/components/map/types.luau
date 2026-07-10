--!strict

local Utils = script.Parent.Parent.Parent.utils
local ThemeUtils = require(Utils.themeUtils)

export type BaseMapProps = {
    Variant: ThemeUtils.BgVariantLayer,
    RowCount: number,
    RowIdx: number
}

return nil
