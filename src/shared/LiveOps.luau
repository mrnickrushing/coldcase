-- COLD CASE · the ninety-day live-ops calendar as data.
-- Pure module: no Roblox services, so it runs under Lune tests too.
-- Every gate takes a launch day number; the server decides what "today" is.
local LiveOps = {}

-- The launch moment in UTC epoch seconds; days roll over at this time of day.
-- While nil the game is pre-launch and every gate reads day 0.
LiveOps.LAUNCH_UTC = 1788998400 :: number? -- 2026-09-10 00:00 UTC

LiveOps.TRADING_UNLOCK_DAY = 28
LiveOps.FOURTH_MAP_DAY = 45
LiveOps.DUOS_DAY = 90

export type Season = {
    id: string,
    name: string,
    opensDay: number,
    closesDay: number, -- first day the season is retired
    crateId: string,
    crateCost: number,
}

LiveOps.SEASONS = {
    {
        id = "S1",
        name = "The Long Night",
        opensDay = 14,
        -- The handbook says both "retired forever on day 90" (14 + a 76-day
        -- countdown) and "Day 76 · Season One closes". Day 90 is used here.
        closesDay = 90,
        crateId = "seasonal",
        -- The server charges this; the lobby quotes Config.SEASONAL_COST as a
        -- pre-replication fallback, so the two must agree. This module cannot
        -- read Config - it requires nothing so Lune can load it, and
        -- `script.Parent` is nil there - so a test pins the two numbers instead.
        crateCost = 600,
    },
} :: { Season }

LiveOps.COIN_BOOSTS = {
    { name = "Double coin weekend", fromDay = 60, toDay = 62, multiplier = 2 },
}

function LiveOps.DayAt(now: number, launchUtc: number?): number
    if not launchUtc or now < launchUtc then
        return 0
    end
    return math.floor((now - launchUtc) / 86400)
end

function LiveOps.IsTradingOpen(day: number): boolean
    return day >= LiveOps.TRADING_UNLOCK_DAY
end

function LiveOps.GetSeason(id: string): Season?
    for _, s in LiveOps.SEASONS do
        if s.id == id then
            return s
        end
    end
    return nil
end

function LiveOps.ActiveSeason(day: number): Season?
    for _, s in LiveOps.SEASONS do
        if day >= s.opensDay and day < s.closesDay then
            return s
        end
    end
    return nil
end

-- A season that has closed never drops again. There is no override for this.
function LiveOps.IsRetired(seasonId: string?, day: number): boolean
    if not seasonId then
        return false
    end
    local s = LiveOps.GetSeason(seasonId)
    return s == nil or day >= s.closesDay
end

function LiveOps.DaysLeftInSeason(day: number): number?
    local s = LiveOps.ActiveSeason(day)
    return s and (s.closesDay - day) or nil
end

function LiveOps.CoinMultiplier(day: number): number
    local m = 1
    for _, b in LiveOps.COIN_BOOSTS do
        if day >= b.fromDay and day <= b.toDay then
            m = math.max(m, b.multiplier)
        end
    end
    return m
end

return LiveOps
