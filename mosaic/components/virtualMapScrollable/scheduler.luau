--!strict

-- A small injected scheduler keeps frame coalescing testable without Roblox
-- frame signals. The supplied schedule function must return a cancellation
-- callback for the queued work.

export type Cancel = () -> ()
export type Schedule = (callback: () -> ()) -> Cancel

export type Coalescer = {
    Request: () -> (),
    Cancel: () -> (),
    Destroy: () -> ()
}

local function Create(
    schedule: Schedule,
    callback: () -> ()
): Coalescer
    local alive = true
    local pendingToken: {}? = nil
    local cancelPending: Cancel? = nil

    local function cancel()
        pendingToken = nil

        local usedCancelPending = cancelPending
        cancelPending = nil

        if usedCancelPending then
            usedCancelPending()
        end
    end

    local function request()
        if not alive or pendingToken then return end

        local token = {}
        pendingToken = token

        local scheduledCancel = schedule(function()
            if pendingToken ~= token then return end

            pendingToken = nil
            cancelPending = nil

            if alive then
                callback()
            end
        end)

        if pendingToken == token then
            cancelPending = scheduledCancel
        else
            -- Also handle an injected scheduler that executes synchronously.
            scheduledCancel()
        end
    end

    local function destroy()
        if not alive then return end

        alive = false
        cancel()
    end

    return {
        Request = request,
        Cancel = cancel,
        Destroy = destroy
    }
end

return {
    Create = Create
}
