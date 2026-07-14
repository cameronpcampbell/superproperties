--!strict

local Packages = script.Parent.Parent.Parent.Parent
local Fusion = require(Packages.fusion)

local Utils = script.Parent.Parent.Parent.utils
local ThemeUtils = require(Utils.themeUtils)

export type BaseMapProps = {
	Variant: ThemeUtils.BgVariantLayer,
	RowCount: Fusion.UsedAs<number>,
	RowIdx: Fusion.UsedAs<number>,
}

export type Item = {
	Key: string,
	Value: any,
	SubItems: { Item }?,
	Collapsed: Fusion.Value<boolean>?,
}

export type Items = { Item }

export type ItemLayout = {
	Item: Item,
	Depth: number,
	CollapsedState: Fusion.Value<boolean>?,
	Children: { ItemLayout },
	ChildrenContentHeight: Fusion.Computed<number>,
	AnimatedChildrenHeight: Fusion.Computed<number>,
	AnimatedHeight: Fusion.Computed<number>,
}

export type RowMetadata = {
	RowCount: number,
	RowIndices: { [ItemLayout]: number },
}

return nil
