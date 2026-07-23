--!strict

export type InstanceHandle = {
    Get: (self: InstanceHandle) -> Instance?,
    Wait: (self: InstanceHandle, timeout: number?) -> Instance?
}

export type Constructor = {
    new: (instance: Instance) -> InstanceHandle
}

return (getfenv() :: any).InstanceHandle :: Constructor
