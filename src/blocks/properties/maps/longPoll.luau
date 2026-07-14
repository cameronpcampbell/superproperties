--!strict

local function LongPoll(
    interval: number,
    callback: () -> ()
): () -> ()
    assert(
        interval > 0 and interval < math.huge,
        "Long poll interval must be finite and positive."
    )

    local active = true
    local scheduledThread: thread? = nil

    local function schedule()
        scheduledThread = task.delay(interval, function()
            scheduledThread = nil
            if not active then return end

            callback()

            if active then schedule() end
        end)
    end

    schedule()

    return function()
        active = false

        if not scheduledThread then return end
        task.cancel(scheduledThread)
        scheduledThread = nil
    end
end

return LongPoll
