--!strict

local GetNextChecked = require("./getNextChecked")

assert(GetNextChecked(false) == true, "false should become true")
assert(GetNextChecked(true) == false, "true should become false")
assert(GetNextChecked("Mixed") == false, "Mixed should become false")

print("getNextChecked verification passed")
