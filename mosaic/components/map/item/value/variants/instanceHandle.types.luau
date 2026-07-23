--!strict

export type InstanceHandle = {
    Get: (self: InstanceHandle) -> Instance?,
    Wait: (self: InstanceHandle, timeout: number?) -> Instance?
}

export type Constructor = {
    new: (instance: Instance) -> InstanceHandle,
    Empty: InstanceHandle,
    IsEmptyTarget: (target: Instance) -> boolean
}

local NativeInstanceHandle =
    (getfenv() :: any).InstanceHandle :: {
        new: (instance: Instance) -> InstanceHandle
    }

local EmptyHandleTargets =
    setmetatable({} :: { [Instance]: boolean }, {
        __mode = "k"
    })

-- SetAttribute deletes an attribute when given nil, but InstanceHandle has no
-- empty constructor. Use a destroyed weakly-referenced target so an empty
-- Instance attribute can be preserved while resolving as Empty.
local emptyTarget = Instance.new("Folder")
local EmptyInstanceHandle = NativeInstanceHandle.new(emptyTarget)

EmptyHandleTargets[emptyTarget] = true
emptyTarget:Destroy()

return {
    new = NativeInstanceHandle.new,
    Empty = EmptyInstanceHandle,
    IsEmptyTarget = function(target: Instance): boolean
        return EmptyHandleTargets[target] == true
    end
} :: Constructor
