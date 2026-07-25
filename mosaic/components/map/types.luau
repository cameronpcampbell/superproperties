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

export type TrySet<T> = (value: T) -> (boolean, string?, T?)
export type TransformValue = (value: any) -> any
export type TryTransformValue =
	(transform: TransformValue) -> (boolean, string?, any?)

export type Item = {
	Key: string,
	KeyChildren: { Fusion.Child }?,
	KeyWritable: boolean?,
	TrySetKey: TrySet<string>?,
	Value: Fusion.UsedAs<any?>,
	ComparisonValues: { Fusion.UsedAs<any?> }?,
	ValueType: string?,
	ValueChildren: { Fusion.Child }?,
	ValueWritable: boolean?,
	TrySetValue: TrySet<any>?,
	TryTransformValue: TryTransformValue?,
	DisplayAsWritable: boolean?,
	SubItems: { Item }?,
	Collapsed: Fusion.Value<boolean>?,
}

export type Items = { Item }

export type IntrinsicAccessor = {
	Read: (rootValue: any) -> any,
	Write: (rootValue: any, value: any) -> any,
}

export type IntrinsicItem = {
	Key: string,
	KeyChildren: { Fusion.Child }?,
	Value: IntrinsicAccessor,
	ValueChildren: { Fusion.Child }?,
	SubItems: { IntrinsicItem }?,
	Collapsed: Fusion.Value<boolean>?,
}

export type IntrinsicItems = { IntrinsicItem }

export type ItemLayout = {
	Item: Item | IntrinsicItem,
	ResolvedValue: Fusion.UsedAs<any?>,
	ValueType: string?,
	Mixed: Fusion.UsedAs<boolean>,
	TrySetKey: TrySet<string>?,
	TrySetValue: TrySet<any>?,
	KeyWritable: boolean,
	ValueWritable: boolean,
	DisplayAsWritable: boolean,
	KeyFocusState: Fusion.Value<boolean>,
	KeyFocusElevationState: Fusion.Value<boolean>,
	ValueFocusState: Fusion.Value<boolean>,
	ValueFocusElevationState: Fusion.Value<boolean>,
	Depth: number,
	CanBecomeMapBottom: boolean,
	CollapsedState: Fusion.Value<boolean>?,
	ChildrenMounted: Fusion.UsedAs<boolean>,
	ChildrenReveal: Fusion.UsedAs<number>?,
	CornersCollapsed: Fusion.UsedAs<boolean>?,
	Children: { ItemLayout },
	ChildrenContentHeight: Fusion.UsedAs<number>,
	AnimatedChildrenHeight: Fusion.UsedAs<number>,
	AnimatedHeight: Fusion.UsedAs<number>,
}

export type RowMetadata = {
	RowCount: number,
	RowIndices: { [ItemLayout]: number },
}

return nil
