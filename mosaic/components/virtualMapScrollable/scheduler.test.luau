--!strict

local Scheduler = require("./scheduler")

type ScheduledWork = {
    Active: boolean,
    Callback: () -> ()
}

local scheduledWork = {} :: { ScheduledWork }
local refreshCount = 0

local function Schedule(callback: () -> ()): () -> ()
    local work = {
        Active = true,
        Callback = callback
    }
    table.insert(scheduledWork, work)

    return function()
        work.Active = false
    end
end

local function RunScheduledWork(workIdx: number)
    local work = assert(
        scheduledWork[workIdx],
        `Missing scheduled work {workIdx}.`
    )
    if work.Active then
        work.Callback()
    end
end

local coalescer = Scheduler.Create(Schedule, function()
    refreshCount += 1
end)

coalescer.Request()
coalescer.Request()
coalescer.Request()

assert(#scheduledWork == 1, "requests in one frame must coalesce")
RunScheduledWork(1)
assert(refreshCount == 1, "coalesced work must refresh once")

coalescer.Request()
assert(#scheduledWork == 2, "a later frame must schedule new work")
coalescer.Cancel()
RunScheduledWork(2)
assert(refreshCount == 1, "cancelled work must not refresh")

coalescer.Request()
assert(#scheduledWork == 3, "work must schedule after cancellation")
coalescer.Destroy()
RunScheduledWork(3)
assert(refreshCount == 1, "destroyed work must not refresh")

coalescer.Request()
assert(
    #scheduledWork == 3,
    "destroyed coalescer must reject future work"
)

local synchronousCancelCount = 0
local synchronousRefreshCount = 0
local synchronousCoalescer = Scheduler.Create(function(callback)
    callback()

    return function()
        synchronousCancelCount += 1
    end
end, function()
    synchronousRefreshCount += 1
end)

synchronousCoalescer.Request()
synchronousCoalescer.Request()
assert(
    synchronousRefreshCount == 2,
    "synchronous scheduler must release each completed request"
)
assert(
    synchronousCancelCount == 2,
    "synchronously completed work must release its handle"
)

print("virtualMapScrollableScheduler verification passed")
