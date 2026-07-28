--!strict

local ResolveOptionalBoolean = require("./resolveOptionalBoolean")

assert(
    ResolveOptionalBoolean(nil, true) == true,
    "nil should use the provided default"
)
assert(
    ResolveOptionalBoolean(true, false) == true,
    "true should remain true"
)
assert(
    ResolveOptionalBoolean(false, true) == false,
    "false should remain false"
)

print("resolveOptionalBoolean verification passed")
