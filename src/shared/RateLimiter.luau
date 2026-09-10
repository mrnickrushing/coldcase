-- Fixed one-second window rate limiter with strike tracking.
-- Pure module (no Roblox services) so it can be unit tested under Lune.
local RateLimiter = {}
RateLimiter.__index = RateLimiter

export type RateLimiter = typeof(setmetatable(
    {} :: {
        limit: number,
        strikesToKick: number,
        strikeWindow: number,
        state: { [any]: { sec: number, count: number, struck: boolean, strikes: { number } } },
    },
    RateLimiter
))

function RateLimiter.new(
    limitPerSec: number,
    strikesToKick: number,
    strikeWindow: number
): RateLimiter
    return setmetatable({
        limit = limitPerSec,
        strikesToKick = strikesToKick,
        strikeWindow = strikeWindow,
        state = {},
    }, RateLimiter)
end

-- Returns allowed, shouldKick
function RateLimiter.Hit(self: RateLimiter, key: any, now: number): (boolean, boolean)
    local st = self.state[key]
    if not st then
        st = { sec = -1, count = 0, struck = false, strikes = {} }
        self.state[key] = st
    end

    local sec = math.floor(now)
    if sec ~= st.sec then
        st.sec, st.count, st.struck = sec, 0, false
    end
    st.count += 1
    if st.count <= self.limit then
        return true, false
    end

    if not st.struck then
        st.struck = true
        table.insert(st.strikes, sec)
        local cutoff = sec - self.strikeWindow
        while #st.strikes > 0 and st.strikes[1] <= cutoff do
            table.remove(st.strikes, 1)
        end
    end
    return false, #st.strikes >= self.strikesToKick
end

function RateLimiter.Remove(self: RateLimiter, key: any)
    self.state[key] = nil
end

return RateLimiter
