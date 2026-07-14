--!strict

export type Options = {
    MinInterval: number,
    MaxInterval: number,
    BackoffFactor: number?
}

local DefaultBackoffFactor = 1.5

local function LongPoll(
    options: Options,
    callback: () -> boolean
): () -> ()
    local minInterval = options.MinInterval
    local maxInterval = options.MaxInterval
    local backoffFactor =
        options.BackoffFactor or DefaultBackoffFactor

    assert(
        minInterval > 0 and minInterval < math.huge,
        "Minimum poll interval must be finite and positive."
    )
    assert(
        maxInterval >= minInterval and maxInterval < math.huge,
        "Maximum poll interval must be finite and at least the minimum."
    )
    assert(
        backoffFactor > 1 and backoffFactor < math.huge,
        "Poll backoff factor must be finite and greater than one."
    )

    local active = true
    local currentInterval = minInterval
    local scheduledThread: thread? = nil

    local function schedule()
        scheduledThread = task.delay(currentInterval, function()
            scheduledThread = nil
            if not active then return end

            local foundChanges = callback()
            currentInterval =
                if foundChanges then minInterval
                else math.min(
                    currentInterval * backoffFactor,
                    maxInterval
                )

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
