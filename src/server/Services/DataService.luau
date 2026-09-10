-- ProfileStore wrapper plus per-session counters for analytics.
-- In Studio without API access ProfileStore falls back to its mock store,
-- so playtests work either way (data just will not persist).
local Players = game:GetService("Players")
local ProfileStore = require(game.ServerScriptService.Packages.ProfileStore)
local Config = require(game.ReplicatedStorage.Shared.Config)
local Analytics = require(script.Parent.Analytics)
local Remotes = game.ReplicatedStorage.Remotes

local TEMPLATE = {
    coins = Config.STARTING_COINS,
    xp = 0,
    rank = 1,
    inventory = {}, -- { {id="nocturne", uid="...", at=0, effect="frost"?} }
    equipped = { knife = "ash", gun = "ledger" },
    passes = {}, -- { vip = true }
    seasonalKeys = 0,
    purchases = {}, -- [PurchaseId] = os.time(), so a receipt is never granted twice
    stats = { rounds = 0, wins = 0, murdererWins = 0 },
    lastLogin = 0,
    streak = 0,
    onboarding = { freeCrate = false, rankGift = false },
    hintsSeen = {}, -- { move = true, examine = true, coins = true }
}

local Store = ProfileStore.New("PlayerData_v1", TEMPLATE)
local DataService = {}
local profiles = {}
local sessions = {}

-- Fires with (player) once their profile is live. Read data with :Get —
-- BindableEvents deep-copy tables, so data itself is never passed.
DataService.Loaded = Instance.new("BindableEvent")

export type Session = {
    joined: number,
    rounds: number,
    coinsEarned: number,
    isNew: boolean,
    lastScreen: string,
}

function DataService:Load(plr: Player)
    local profile = Store:StartSessionAsync("p_" .. plr.UserId, {
        Cancel = function()
            return plr.Parent ~= Players
        end,
    })
    if not profile then
        if plr.Parent == Players then
            plr:Kick("Data failed to load. Please rejoin.")
        end
        return
    end

    profile:AddUserId(plr.UserId) -- GDPR compliance
    profile:Reconcile() -- fill in keys added since this save was written

    profile.OnSessionEnd:Connect(function()
        profiles[plr] = nil
        plr:Kick("Session ended. Please rejoin.")
    end)

    if plr.Parent ~= Players then
        profile:EndSession()
        return
    end

    local data = profile.Data
    sessions[plr] = {
        joined = os.clock(),
        rounds = 0,
        coinsEarned = 0,
        isNew = data.lastLogin == 0,
        lastScreen = "LOBBY",
    }
    profiles[plr] = profile
    plr:SetAttribute("Rank", data.rank) -- public: shown in the lobby list

    local reward = self:ApplyLoginStreak(data)
    if reward > 0 then
        Analytics.CoinsEarned(plr, "streak", reward, data.coins, 0)
        Remotes.Notify:FireClient(plr, ("Day %d streak · +%d coins"):format(data.streak, reward))
    end

    self:PushToClient(plr)
    Analytics.Funnel(plr, Analytics.FUNNEL.JOINED)
    DataService.Loaded:Fire(plr)
end

-- 50 coins on day one, +50 per consecutive day, capped at 400 (day eight)
function DataService:ApplyLoginStreak(data): number
    local today = math.floor(os.time() / 86400)
    if data.lastLogin == today then
        return 0
    end
    data.streak = (today - data.lastLogin == 1) and (data.streak + 1) or 1
    data.lastLogin = today
    local reward = math.min(Config.STREAK_COINS_PER_DAY * data.streak, Config.STREAK_COINS_MAX)
    data.coins += reward
    return reward
end

function DataService:Get(plr: Player)
    local p = profiles[plr]
    return p and p.Data or nil
end

function DataService:GetSession(plr: Player): Session?
    return sessions[plr]
end

function DataService:SetScreen(plr: Player, screen: string)
    local s = sessions[plr]
    if s then
        s.lastScreen = screen
    end
end

function DataService:PushToClient(plr: Player)
    local data = self:Get(plr)
    if data then
        Remotes.DataChanged:FireClient(plr, data)
    end
end

Players.PlayerRemoving:Connect(function(plr)
    local s = sessions[plr]
    if s then
        local seconds = os.clock() - s.joined
        Analytics.SessionEnd(plr, seconds, s.rounds, s.coinsEarned, s.isNew)
        if s.isNew then
            Analytics.FirstSessionExit(plr, s.lastScreen, seconds, s.rounds)
        end
        sessions[plr] = nil
    end
    local p = profiles[plr]
    if p then
        p:EndSession()
    end
end)

return DataService
