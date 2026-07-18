--!strict

local Types = require(script.types)
local Vector = require(script.vector)
local Vector2 = require(script.vector2)

export type ValueVariantProps<T> = Types.ValueVariantProps<T>
export type ValueVariantFn<T> = Types.ValueVariantFn<T>

return {
    string = require(script.string),
    number = require(script.number),
    boolean = require(script.boolean),
    EnumItem = require(script.enumItem),
    Color3 = require(script.color),
    BrickColor = require(script.color),
    Vector2 = Vector2,
    Vector3 = Vector,
    vector = Vector,
    UDim = require(script.udim),
    Instance = require(script.instance),
    Default = require(script.default)
}
