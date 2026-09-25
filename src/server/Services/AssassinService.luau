-- Assassin free-for-all: each player is handed a target to hunt. You can knife
-- anyone, but your target is who to find; when your target dies you're given a
-- new living one, so there is always someone to chase. Last blade standing wins
-- (RoundService owns the win condition).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modes = require(ReplicatedStorage.Shared.Modes)
local Remotes = ReplicatedStorage.Remotes
local RoleService = require(script.Parent.RoleService)
local Participant = require(script.Parent.Participant)

local AssassinService = {}
local round: any = nil
local target: { [any]: any } = {}

function AssassinService:BindRound(roundService)
    round = roundService
end

local function ffa(): boolean
    return round ~= nil and Modes.Get(ReplicatedStorage:GetAttribute("Mode")).ffa == true
end

local function livingOthers(plr): { any }
    local out = {}
    for _, p in RoleService:Participants() do
        if p ~= plr and round:IsAlive(p) then
            table.insert(out, p)
        end
    end
    return out
end

local function assign(plr)
    local opts = livingOthers(plr)
    if #opts == 0 then
        target[plr] = nil
        return
    end
    local t = opts[math.random(#opts)]
    target[plr] = t
    if not Participant.IsBot(plr) then
        Remotes.Notify:FireClient(plr, ("Your target: %s"):format(t.Name))
    end
end

function AssassinService:OnRoundStart()
    target = {}
    if not ffa() then
        return
    end
    for _, p in RoleService:Participants() do
        if round:IsAlive(p) then
            assign(p)
        end
    end
end

-- A death: anyone hunting the fallen player is handed a fresh target.
function AssassinService:OnDeath(victim)
    if not ffa() then
        return
    end
    target[victim] = nil
    for p, t in target do
        if t == victim and round:IsAlive(p) then
            assign(p)
        end
    end
end

return AssassinService
