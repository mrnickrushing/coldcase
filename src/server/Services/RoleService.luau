local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Config = require(game.ReplicatedStorage.Shared.Config)
local Shuffle = require(game.ReplicatedStorage.Shared.Shuffle)
local DataService = require(script.Parent.DataService)
local Analytics = require(script.Parent.Analytics)
local CosmeticService = require(script.Parent.CosmeticService)
local Participant = require(script.Parent.Participant)
local Remotes = game.ReplicatedStorage.Remotes

local RoleService = {}
local roles = {} -- [Player] = "murderer" | "sheriff" | "innocent" | "hero" | ...
local sinceMurderer = {} -- [Player] = rounds since they last held the knife
local PISTOL_ROLES: { [string]: boolean } = Config.PISTOL_ROLES :: any

-- Weighted draw so nobody gets the knife twice in three rounds while a
-- friend goes ten without it.
local function drawMurderer(pool)
    local weights, total = {}, 0
    for i, plr in pool do
        local since = sinceMurderer[plr] or 99
        local w = math.clamp(since / Config.MURDERER_COOLOFF, 0.1, 1) * 100
        weights[i] = w
        total += w
    end
    local n = math.random() * total
    for i, w in weights do
        n -= w
        if n <= 0 then
            return table.remove(pool, i)
        end
    end
    return table.remove(pool)
end

local function isFirstRound(plr: Player): boolean
    local data = DataService:Get(plr)
    return data ~= nil and data.stats.rounds == 0
end

function RoleService:Assign(participants: { Player })
    roles = {}
    local count = #participants
    local murderers = count >= Config.SECOND_MURDERER_AT and 2 or 1
    local sheriffs = count >= Config.SECOND_SHERIFF_AT and 2 or 1

    -- Onboarding: a player's first round is always innocent. Newcomers only
    -- enter the special-role pool when there are not enough veterans to fill it.
    local pool, newcomers = {}, {}
    for _, plr in participants do
        table.insert(isFirstRound(plr) and newcomers or pool, plr)
    end
    Shuffle.Shuffle(pool)
    Shuffle.Shuffle(newcomers)
    while #pool < murderers + sheriffs and #newcomers > 0 do
        table.insert(pool, table.remove(newcomers))
    end

    for _ = 1, murderers do
        local m = drawMurderer(pool)
        if m then
            roles[m] = "murderer"
        end
    end
    for _ = 1, sheriffs do
        local s = table.remove(pool)
        if s then
            roles[s] = "sheriff"
        end
    end
    -- An NPC medic never revives anyone and an NPC snitch's reveal reaches no
    -- screen, so these two lean toward a person. Only a lean: preferring a
    -- human every time handed the same player medic round after round.
    local function drawPreferHuman(): Player?
        if math.random() < 0.5 then
            for i = #pool, 1, -1 do
                if not Participant.IsBot(pool[i]) then
                    return table.remove(pool, i)
                end
            end
        end
        return table.remove(pool)
    end
    -- A medic can bring back a person or an NPC (BotService rebuilds the
    -- body), so a round filled with NPCs is a full round for the medic too.
    if count >= Config.MEDIC_AT and #pool > 2 then
        local medic = drawPreferHuman()
        if medic then
            roles[medic] = "medic"
        end
    end
    if count >= Config.SNITCH_AT and #pool > 2 then
        local snitch = drawPreferHuman()
        if snitch then
            roles[snitch] = "snitch"
        end
    end
    for _, plr in pool do
        roles[plr] = "innocent"
    end
    for _, plr in newcomers do
        roles[plr] = "innocent"
    end

    -- Studio only: set ServerStorage.ForceRole = "medic" to play a role on
    -- demand. The first person swaps roles with whoever drew it, so the
    -- round still has exactly the roles it would have had.
    local force = RunService:IsStudio() and ServerStorage:GetAttribute("ForceRole")
    if type(force) == "string" then
        for _, plr in participants do
            if not Participant.IsBot(plr) then
                for other, role in roles do
                    if role == force then
                        roles[other] = roles[plr]
                        break
                    end
                end
                roles[plr] = force
                break
            end
        end
    end

    for _, plr in participants do
        self:Arm(plr)
        if Participant.IsBot(plr) then
            continue -- an NPC has no client, no history and no profile
        end
        if roles[plr] == "murderer" then
            sinceMurderer[plr] = 0
        else
            sinceMurderer[plr] = (sinceMurderer[plr] or 0) + 1
        end
        -- CRITICAL: FireClient per player, never FireAllClients.
        -- Anything the client receives, an exploiter reads.
        Remotes.RoleAssigned:FireClient(plr, roles[plr])

        local data = DataService:Get(plr)
        Analytics.RoleAssigned(plr, roles[plr], data and data.rank or 0, isFirstRound(plr))
    end
end

-- Weapons are carried hidden and drawn by CombatService on each use. A knife
-- held all round would name the murderer to anyone who looks.
function RoleService:Arm(plr: Player)
    local role = roles[plr]
    if role == "murderer" then
        CosmeticService:GiveWeapon(plr, "knife")
    elseif role == "sheriff" or role == "hero" then
        CosmeticService:GiveWeapon(plr, "gun")
    end
end

function RoleService:Get(plr: Player): string?
    return roles[plr]
end

-- Taking the fallen sheriff's pistol. Every unarmed civilian role can, not
-- innocents alone (Config.PISTOL_ROLES): a medic or snitch who cannot pick up
-- the gun in front of them reads as a broken game. Whoever takes it becomes
-- the hero, so a medic trades the rest of their kit for the revolver -
-- CombatService tells them so.
function RoleService:MakeHero(plr: Player): boolean
    local role = roles[plr]
    if not (role and PISTOL_ROLES[role]) then
        return false
    end
    roles[plr] = "hero"
    if not Participant.IsBot(plr) then
        Remotes.RoleAssigned:FireClient(plr, "hero")
    end
    self:Arm(plr)
    return true
end

-- Snitch: at 30s remaining, the snitch and the murderer(s) learn each other.
-- A full round can hold two murderers (SECOND_MURDERER_AT), so the snitch
-- learns every murderer and every murderer learns the snitch - a single
-- `murderer` variable would have named only whichever the table iterated last
-- and left the other unwarned.
function RoleService:RevealSnitch()
    local snitch
    local murderers = {}
    for plr, role in roles do
        if role == "snitch" then
            snitch = plr
        elseif role == "murderer" then
            table.insert(murderers, plr)
        end
    end
    if not (snitch and #murderers > 0) then
        return
    end
    if not Participant.IsBot(snitch) then
        local names = {}
        for _, murderer in murderers do
            table.insert(names, murderer.Name)
        end
        Remotes.RoleAssigned:FireClient(snitch, "snitch", table.concat(names, " and "))
    end
    for _, murderer in murderers do
        if not Participant.IsBot(murderer) then
            Remotes.RoleAssigned:FireClient(murderer, "murderer", snitch.Name)
        end
    end
end

-- Only ever called AFTER the round has resolved
function RoleService:GetPublicReveal(): { [string]: string }
    local out = {}
    for plr, role in roles do
        out[plr.Name] = role
    end
    return out
end

function RoleService:Clear()
    roles = {}
end

Players.PlayerRemoving:Connect(function(plr)
    sinceMurderer[plr] = nil
end)

return RoleService
