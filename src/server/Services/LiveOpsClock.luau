-- Server-side "what launch day is it". In Studio, set the attribute
-- ServerStorage.LiveOpsDay (number) to preview any day of the calendar.
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local LiveOps = require(game.ReplicatedStorage.Shared.LiveOps)

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

return LiveOpsClock
