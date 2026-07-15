--!strict

local Packages = script.Parent.Parent.Parent.Parent
local Fusion = require(Packages.fusion)

local Computed = Fusion.Computed

type BinaryOperation = (number, number) -> number

local function MakeBinaryOperation(operation: BinaryOperation)
    return function(
        scope: Fusion.Scope<typeof(Fusion)>,
        left: Fusion.UsedAs<number>,
        right: Fusion.UsedAs<number>
    ): Fusion.Computed<number>
        return Computed(scope, function(use: Fusion.Use)
            return operation(
                use<<number>>(left),
                use<<number>>(right)
            )
        end)
    end
end

local Add = MakeBinaryOperation(function(left, right)
    return left + right
end)

local Subtract = MakeBinaryOperation(function(left, right)
    return left - right
end)

local Pow = MakeBinaryOperation(function(left, right)
    return left ^ right
end)

local Mod = MakeBinaryOperation(function(left, right)
    return left % right
end)

local Multiply = MakeBinaryOperation(function(left, right)
    return left * right
end)

local Divide = MakeBinaryOperation(function(left, right)
    return left / right
end)

local FloorDivide = MakeBinaryOperation(function(left, right)
    return left // right
end)

return {
    Add = Add,
    Subtract = Subtract,
    Pow = Pow,
    Mod = Mod,
    Multiply = Multiply,
    Divide = Divide,
    FloorDivide = FloorDivide
}
