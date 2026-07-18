--!strict

local Packages =
    script.Parent.Parent.Parent.Parent.Parent.Parent.Parent.Parent.Parent.packages
local Lexuau = require(Packages.lexuau)

return Lexuau.new<<nil>>({
    skip = "[ \t\n\r\f]+",
    init_state = function()
        return nil
    end,

    subpatterns = {
        numsect = "_*[\\d]+_*",
        num = "((?&numsect)+\\.)?(?&numsect)+|\\.(?&numsect)"
    },

    patterns = {
        number = "(?&num)",
        comma = ",",
        sign = "[+-]"
    }
})
