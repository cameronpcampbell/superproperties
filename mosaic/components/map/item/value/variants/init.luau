--!strict

local Types = require(script.types)
local Vector = require(script.vector)
local InstanceValue = require(script.instance)

export type ValueVariantProps<T> = Types.ValueVariantProps<T>
export type ValueVariantFn<T> = Types.ValueVariantFn<T>

return {
    string = require(script.string),
    number = require(script.number),
    boolean = require(script.boolean),
    EnumItem = require(script.enumItem),
    Color3 = require(script.color),
    BrickColor = require(script.color),
    Vector2 = require(script.vector2),
    Vector3 = Vector,
    vector = Vector,
    CFrame = require(script.cframe),
    UDim = require(script.udim),
    UDim2 = require(script.udim2),
    Instance = InstanceValue,
    InstanceHandle = InstanceValue,
    Default = require(script.default)
}
