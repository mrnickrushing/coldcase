local Players = game:GetService("Players")
local Config = require(game.ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local Analytics = require(script.Parent.Analytics)
local Remotes = game.ReplicatedStorage.Remotes

local RoleService = {}
local roles = {} -- [Player] = "murderer" | "sheriff" | "innocent" | "hero" | ...
local sinceMurderer = {} -- [Player] = rounds since they last held the knife

local function shuffle(t)
    for i = #t, 2, -1 do
        local j = math.random(i)
        t[i], t[j] = t[j], t[i]
    end
end

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
    shuffle(pool)
    shuffle(newcomers)
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
    if count >= Config.MEDIC_AT and #pool > 2 then
        roles[table.remove(pool)] = "medic"
    end
    if count >= Config.SNITCH_AT and #pool > 2 then
        roles[table.remove(pool)] = "snitch"
    end
    for _, plr in pool do
        roles[plr] = "innocent"
    end
    for _, plr in newcomers do
        roles[plr] = "innocent"
    end

    for _, plr in participants do
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

function RoleService:Get(plr: Player): string?
    return roles[plr]
end

function RoleService:MakeHero(plr: Player): boolean
    if roles[plr] ~= "innocent" then
        return false
    end
    roles[plr] = "hero"
    Remotes.RoleAssigned:FireClient(plr, "hero")
    return true
end

-- Snitch: at 30s remaining, the snitch and the murderer learn each other
function RoleService:RevealSnitch()
    local snitch, murderer
    for plr, role in roles do
        if role == "snitch" then
            snitch = plr
        end
        if role == "murderer" then
            murderer = plr
        end
    end
    if snitch and murderer then
        Remotes.RoleAssigned:FireClient(snitch, "snitch", murderer.Name)
        Remotes.RoleAssigned:FireClient(murderer, "murderer", snitch.Name)
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
