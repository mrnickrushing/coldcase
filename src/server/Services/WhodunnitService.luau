-- Whodunnit: the town convicts the killer by accusation, not the gun. Each
-- living player may name one living suspect; when a suspect draws accusations
-- from a majority of the living human voters they are convicted. If they are the
-- murderer, the town wins; if not, the town has lynched one of its own and the
-- round plays on with a fresh slate.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modes = require(ReplicatedStorage.Shared.Modes)
local Remotes = ReplicatedStorage.Remotes
local RoleService = require(script.Parent.RoleService)
local Participant = require(script.Parent.Participant)

local WhodunnitService = {}
local round: any = nil
local accusation: { [any]: any } = {} -- voter -> accused participant

function WhodunnitService:BindRound(roundService)
    round = roundService
end

local function active(): boolean
    return round ~= nil and Modes.Get(ReplicatedStorage:GetAttribute("Mode")).vote == true
end

-- Humans still alive who may cast a vote (bots do not accuse).
local function livingVoters(): number
    local n = 0
    for _, p in RoleService:Participants() do
        if not Participant.IsBot(p) and round:IsAlive(p) then
            n += 1
        end
    end
    return n
end

local function tally(): ({ [string]: number }, any, number)
    local counts = {}
    local top, topN = nil, 0
    for voter, accused in accusation do
        if round:IsAlive(voter) and round:IsAlive(accused) then
            local name = accused.Name
            counts[name] = (counts[name] or 0) + 1
            if counts[name] > topN then
                top, topN = accused, counts[name]
            end
        end
    end
    return counts, top, topN
end

-- The living suspects (players and bots) the town may vote on.
local function suspects(): { string }
    local out = {}
    for _, p in RoleService:Participants() do
        if round:IsAlive(p) then
            table.insert(out, p.Name)
        end
    end
    table.sort(out)
    return out
end

-- Push the board to every client: outside Whodunnit it clears theirs.
local function broadcast()
    if not active() then
        Remotes.AccuseTally:FireAllClients({ suspects = {}, counts = {} })
        return
    end
    Remotes.AccuseTally:FireAllClients({ suspects = suspects(), counts = (tally()) })
end

function WhodunnitService:Reset()
    accusation = {}
    broadcast()
end

function WhodunnitService:Convict(target)
    if RoleService:Get(target) == "murderer" then
        round:Resolve("innocents", "convicted")
    else
        Remotes.Notify:FireAllClients(("%s was convicted — and innocent."):format(target.Name))
        self:Reset()
        round:MarkDead(target, nil, "convicted")
    end
end

function WhodunnitService:Accuse(plr, targetName)
    if not active() or not round:IsAlive(plr) or type(targetName) ~= "string" then
        return
    end
    local target
    for _, p in RoleService:Participants() do
        if p.Name == targetName and p ~= plr and round:IsAlive(p) then
            target = p
            break
        end
    end
    if not target then
        return
    end
    accusation[plr] = target
    broadcast()
    local _, top, topN = tally()
    if top and topN > livingVoters() / 2 then
        self:Convict(top)
    end
end

-- Called when someone dies: drop stale votes, re-broadcast, and convict if a
-- death has tipped a suspect over the (now smaller) majority.
function WhodunnitService:Recheck()
    if not active() then
        return
    end
    broadcast()
    local _, top, topN = tally()
    if top and topN > livingVoters() / 2 then
        task.defer(function()
            self:Convict(top)
        end)
    end
end

return WhodunnitService
