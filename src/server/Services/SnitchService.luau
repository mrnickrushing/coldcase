-- The snitch's investigation. Reading a body builds a private suspect board
-- from its clues, and once the snitch has read enough bodies (or the 30s reveal
-- fires) they may EXPOSE the real killer to everyone - once.
-- Handbook rule: the snitch trades identity, not advantage. Expose names the
-- server's true killer (never a guess) and does NOT end the round; the sheriff
-- still has to stop them, and the murderer already knows the snitch by then.
local Players = game:GetService("Players")
local Shared = game.ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Remotes = game.ReplicatedStorage.Remotes
local RoleService = require(script.Parent.RoleService)
local EvidenceService = require(script.Parent.EvidenceService)
local Participant = require(script.Parent.Participant)

local SnitchService = {}
local round: any = nil

-- [snitch] = { fibres={[band]=true}, prefixes={[prefix]=true}, examined=n,
--             revealed=bool, used=bool }
local state: { [any]: any } = {}

function SnitchService:BindRound(roundService)
    round = roundService
end

local function ev(snitch)
    local e = state[snitch]
    if not e then
        e = { fibres = {}, prefixes = {}, examined = 0, revealed = false, used = false }
        state[snitch] = e
    end
    return e
end

local function alive(p): boolean
    return round == nil or round:IsAlive(p)
end

-- Score one living suspect against what the snitch has gathered. A fibre band
-- clears or keeps a suspect; a name fragment pins them.
local function score(e, name: string, band: string): (number, string)
    local haveFibre = next(e.fibres) ~= nil
    local fibreMatch = e.fibres[band] == true
    local prefixMatch = false
    for pre in e.prefixes do
        if name:sub(1, #pre):lower() == pre:lower() then
            prefixMatch = true
            break
        end
    end
    if haveFibre and not fibreMatch then
        return 0, "cleared"
    end
    if prefixMatch then
        return (fibreMatch and 4 or 3), (fibreMatch and "near-certain" or "likely")
    end
    if fibreMatch then
        return 2, "person of interest"
    end
    return 1, "unknown"
end

function SnitchService:BuildBoard(snitch): { any }
    local e = ev(snitch)
    local rows = {}
    for _, p in RoleService:Participants() do
        if p ~= snitch and alive(p) then
            local band = EvidenceService:ColourBandOf(p)
            local bar, label = score(e, p.Name, band)
            table.insert(rows, { name = p.Name, bar = bar, label = label })
        end
    end
    table.sort(rows, function(a, b)
        if a.bar ~= b.bar then
            return a.bar > b.bar
        end
        return a.name < b.name
    end)
    return rows
end

local function canExpose(e): boolean
    return not e.used and (e.revealed or e.examined >= Config.SNITCH_EXPOSE_CLUES)
end

function SnitchService:Push(snitch)
    if Participant.IsBot(snitch) then
        return -- an NPC snitch has no client to send a board to
    end
    local e = ev(snitch)
    Remotes.Deduction:FireClient(snitch, {
        suspects = self:BuildBoard(snitch),
        canExpose = canExpose(e),
        used = e.used,
    })
end

-- EvidenceService calls this when a snitch reads a body.
function SnitchService:AddClue(snitch, clue)
    local e = ev(snitch)
    e.examined += 1
    if clue.fibre then
        e.fibres[clue.fibre] = true
    end
    if clue.prefix then
        e.prefixes[clue.prefix] = true
    end
    self:Push(snitch)
end

-- The 30s mutual reveal has fired: every human snitch may now Expose.
function SnitchService:OnReveal()
    for _, p in RoleService:Participants() do
        if RoleService:Get(p) == "snitch" then
            ev(p).revealed = true
            self:Push(p)
        end
    end
end

function SnitchService:RequestExpose(plr: Player)
    if RoleService:Get(plr) ~= "snitch" or not alive(plr) then
        return
    end
    local e = ev(plr)
    if not canExpose(e) then
        Remotes.Notify:FireClient(plr, "You do not have enough on the killer yet.")
        return
    end
    local murderers = RoleService:Murderers()
    if #murderers == 0 then
        return
    end
    e.used = true
    local names = {}
    for _, m in murderers do
        table.insert(names, m.Name)
    end
    -- Everyone hears it and sees the killer light up; the round runs on.
    Remotes.Expose:FireAllClients(names, Config.SNITCH_EXPOSE_HIGHLIGHT)
    self:Push(plr)
end

function SnitchService:Clear()
    state = {}
end

Players.PlayerRemoving:Connect(function(plr)
    state[plr] = nil
end)

return SnitchService
