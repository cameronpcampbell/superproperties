--!strict

local Packages =
    script.Parent.Parent.Parent.Parent.Parent.Parent.Parent.Parent.Parent.packages
local Fusion = require(Packages.fusion)
local New = Fusion.New

return function(scope: Fusion.Scope): Instance
    return New(scope, "UIPadding") {
        PaddingLeft = UDim.new(0, 6),
        PaddingRight = UDim.new(0, 6)
    }
end
