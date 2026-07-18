--!strict

local Packages = script.Parent.Parent.Parent.Parent
local Supercorner = require(Packages.supercorner)

local Fusion = require(Packages.fusion)
local New, Children, Value, Peek =
    Fusion.New, Fusion.Children, Fusion.Value, Fusion.peek

type SelectMenuItemProps = {}

local function SelectMenuItem(
    scope: Fusion.Scope,
    props: SelectMenuItemProps
)
    return New(scope, "")
end

return SelectMenuItem
