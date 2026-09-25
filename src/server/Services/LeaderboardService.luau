-- Global leaderboards: most round wins, most murderer escapes, richest
-- collection. Backed by OrderedDataStores, which are live-only - in Studio
-- without API access every call is wrapped so the boards are simply empty
-- rather than erroring. Names are resolved once and cached.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local Shared = game.ReplicatedStorage.Shared
local Shop = require(Shared.Shop)
local Remotes = game.ReplicatedStorage.Remotes
local Participant = require(script.Parent.Participant)

-- key: the field on the payload; stat: how to read it from a player's data.
local BOARDS = {
    { key = "wins", title = "TOP DETECTIVES", store = "lb_wins_v1" },
    { key = "killer", title = "TOP KILLERS", store = "lb_killer_v1" },
    { key = "worth", title = "RICHEST", store = "lb_worth_v1" },
}
local TOP_N = 8
local REFRESH = 60

local LeaderboardService = {}
local stores: { [string]: OrderedDataStore } = {}
for _, b in BOARDS do
    local ok, s = pcall(function()
        return DataStoreService:GetOrderedDataStore(b.store)
    end)
    if ok then
        stores[b.key] = s
    end
end

local nameCache: { [number]: string } = {}
local function nameFor(userId: number): string
    local cached = nameCache[userId]
    if cached then
        return cached
    end
    local ok, res = pcall(function()
        return Players:GetNameFromUserIdAsync(userId)
    end)
    local name = (ok and res) or ("User" .. userId)
    nameCache[userId] = name
    return name
end

-- Called after a round settles, for each real player. Cheap (rounds are minutes
-- apart), and bots have no profile so they never reach here.
function LeaderboardService:Record(plr: Player, data)
    if Participant.IsBot(plr) then
        return
    end
    local vals = {
        wins = data.stats.wins,
        killer = data.stats.murdererWins,
        worth = Shop.ValueOf(data.inventory),
    }
    for _, b in BOARDS do
        local store = stores[b.key]
        if store then
            pcall(function()
                store:SetAsync(tostring(plr.UserId), vals[b.key])
            end)
        end
    end
end

function LeaderboardService:Refresh()
    local payload = {}
    for _, b in BOARDS do
        local rows = {}
        local store = stores[b.key]
        if store then
            local ok, pages = pcall(function()
                return store:GetSortedAsync(false, TOP_N)
            end)
            if ok then
                for _, entry in pages:GetCurrentPage() do
                    local userId = tonumber(entry.key)
                    if userId and entry.value and entry.value > 0 then
                        table.insert(rows, { name = nameFor(userId), value = entry.value })
                    end
                end
            end
        end
        payload[b.key] = { title = b.title, rows = rows }
    end
    Remotes.Leaderboard:FireAllClients(payload)
    return payload
end

task.spawn(function()
    while true do
        LeaderboardService:Refresh()
        task.wait(REFRESH)
    end
end)

Players.PlayerAdded:Connect(function()
    task.wait(3) -- let the boards settle, then push to the new client
    LeaderboardService:Refresh()
end)

return LeaderboardService
