--!strict
-- Server-side "what launch day is it". In Studio, set the attribute
-- ServerStorage.LiveOpsDay (number) to preview any day of the calendar.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local LiveOps = require(ReplicatedStorage.Shared.LiveOps)

local LiveOpsClock = {}

function LiveOpsClock.Day(): number
    if RunService:IsStudio() then
        local override = ServerStorage:GetAttribute("LiveOpsDay")
        if type(override) == "number" then
            return math.floor(override)
        end
    end
    return LiveOps.DayAt(os.time(), LiveOps.LAUNCH_UTC)
end

-- Publishes the public calendar state as ReplicatedStorage attributes so the
-- client can show the seasonal crate, its countdown, and whether trading is open.
function LiveOpsClock.Publish()
    local day = LiveOpsClock.Day()
    local season = LiveOps.ActiveSeason(day)
    ReplicatedStorage:SetAttribute("LiveOpsDay", day)
    ReplicatedStorage:SetAttribute("SeasonId", season and season.id or nil)
    ReplicatedStorage:SetAttribute("SeasonName", season and season.name or nil)
    ReplicatedStorage:SetAttribute("SeasonDaysLeft", LiveOps.DaysLeftInSeason(day))
    ReplicatedStorage:SetAttribute("SeasonCrateCost", season and season.crateCost or nil)
    ReplicatedStorage:SetAttribute("TradingOpen", LiveOps.IsTradingOpen(day))
    ReplicatedStorage:SetAttribute("TradingOpensDay", LiveOps.TRADING_UNLOCK_DAY)
end

return LiveOpsClock
