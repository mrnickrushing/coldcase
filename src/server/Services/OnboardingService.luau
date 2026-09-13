-- The first ninety seconds (Handbook §02), server side:
--   0:05  one free Locker pull the moment a new player lands
--   hints tracked once per account ("move", "examine", "coins")
--   onboarding funnel steps for analytics
-- Forced-innocent first rounds live in RoleService; the ghost prompts
-- themselves are drawn by the client.
local Players = game:GetService("Players")
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local Analytics = require(script.Parent.Analytics)

local OnboardingService = {}
local HINTS = { move = true, examine = true, coins = true }
local FREE_CRATE_DELAY = 5
local logged: { [Player]: { [any]: boolean } } = {}

-- True the first time a new player's session reaches `key`, false after that
-- and false for anyone who is not new.
local function once(plr: Player, key: any): boolean
    local session = DataService:GetSession(plr)
    if not (session and session.isNew) then
        return false
    end
    logged[plr] = logged[plr] or {}
    if logged[plr][key] then
        return false
    end
    logged[plr][key] = true
    return true
end

local function funnel(plr: Player, step)
    if once(plr, step[1]) then
        Analytics.Funnel(plr, step)
    end
end

local function grantFreeCrate(plr: Player)
    local data = DataService:Get(plr)
    if not data or data.onboarding.freeCrate then
        return
    end
    task.wait(FREE_CRATE_DELAY)
    data = DataService:Get(plr)
    if not data or data.onboarding.freeCrate then
        return
    end
    data.onboarding.freeCrate = true -- flag first; a failed pull is refunded below
    if EconomyService:OpenCrate(plr, "locker", true) then
        funnel(plr, Analytics.FUNNEL.FREE_CRATE)
    else
        data.onboarding.freeCrate = false
    end
end

DataService.Loaded.Event:Connect(function(plr: Player)
    task.spawn(grantFreeCrate, plr)
end)

function OnboardingService:MarkHintSeen(plr: Player, hintId: any)
    if type(hintId) ~= "string" or not HINTS[hintId] then
        return
    end
    local data = DataService:Get(plr)
    if data then
        data.hintsSeen[hintId] = true
    end
end

-- Not a funnel step; see the note on Analytics.FUNNEL. Only reached for a vote
-- the round accepted, so mapName is always one of Config.MAPS.
function OnboardingService:NoteVote(plr: Player, mapName: string)
    if once(plr, "voted") then
        Analytics.FirstVote(plr, mapName)
    end
end

function OnboardingService:NoteRoundStart(participants: { Player })
    for _, plr in participants do
        local session = DataService:GetSession(plr)
        if session then
            funnel(
                plr,
                session.rounds == 0 and Analytics.FUNNEL.FIRST_ROUND_START
                    or Analytics.FUNNEL.SECOND_ROUND_START
            )
        end
    end
end

function OnboardingService:NoteRoundEnd(participants: { Player })
    for _, plr in participants do
        funnel(plr, Analytics.FUNNEL.FIRST_ROUND_END)
    end
end

Players.PlayerRemoving:Connect(function(plr)
    logged[plr] = nil
end)

return OnboardingService
