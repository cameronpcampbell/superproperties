--!strict

local IsPropertyVisible =
    require("./isPropertyVisible")

local instance = {}

assert(IsPropertyVisible(nil, instance, "value"))
assert(IsPropertyVisible(true, instance, "value"))
assert(not IsPropertyVisible(false, instance, "value"))

local receivedInstance: any = nil
local receivedValue: any = nil
local visible = IsPropertyVisible(
    function(candidate, value)
        receivedInstance = candidate
        receivedValue = value
        return value == "visible"
    end,
    instance,
    "visible"
)

assert(visible)
assert(receivedInstance == instance)
assert(receivedValue == "visible")
