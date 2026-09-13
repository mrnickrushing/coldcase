-- COLD CASE · the ten day-one analytics events (Handbook §05).
--
-- Roblox custom events carry one numeric value and at most three custom
-- fields, and each event is capped at 8,000 unique field combinations. So:
--   * the player is the event's player argument, never a field
--   * continuous numbers are the value, or bucketed when used as a field
--   * positions are grid cells (Config.HEATMAP_CELL studs)
--   * high-cardinality lists (trade itemIds) are not sent — see docs/analytics.md
local AnalyticsService = game:GetService("AnalyticsService")
local RunService = game:GetService("RunService")
local Config = require(game.ReplicatedStorage.Shared.Config)

local Analytics = {}
local IS_STUDIO = RunService:IsStudio()

local F1 = Enum.AnalyticsCustomFieldKeys.CustomField01.Name
local F2 = Enum.AnalyticsCustomFieldKeys.CustomField02.Name
local F3 = Enum.AnalyticsCustomFieldKeys.CustomField03.Name

local function fields(a: any?, b: any?, c: any?)
    local out = {}
    if a ~= nil then
        out[F1] = tostring(a)
    end
    if b ~= nil then
        out[F2] = tostring(b)
    end
    if c ~= nil then
        out[F3] = tostring(c)
    end
    return out
end

local function debugLog(name: string, ...)
    if IS_STUDIO then
        print("[Analytics]", name, ...)
    end
end

-- Buckets: stable, low-cardinality labels for a number
function Analytics.Bucket(n: number, edges: { number }): string
    for i, edge in edges do
        if n < edge then
            return i == 1 and ("<" .. edge) or (edges[i - 1] .. "-" .. edge)
        end
    end
    return edges[#edges] .. "+"
end

local RANK_EDGES = { 2, 5, 10, 25, 50 }
local VALUE_EDGES = { 100, 500, 1000, 5000, 20000 }

local function custom(plr: Player, name: string, value: number, f)
    debugLog(name, value, f[F1], f[F2], f[F3])
    pcall(AnalyticsService.LogCustomEvent, AnalyticsService, plr, name, value, f)
end

function Analytics.RoundComplete(
    reporter: Player,
    map: string,
    winner: string,
    duration: number,
    playerCount: number,
    event: string?
)
    -- playerCount is folded into the event field; 3 maps × 2 winners × 6 events × 5 sizes stays well under the cap
    local size = Analytics.Bucket(playerCount, { 6, 8, 10, 12, 14 })
    custom(
        reporter,
        "round_complete",
        math.floor(duration),
        fields(map, winner, (event or "NONE") .. "|" .. size)
    )
end

function Analytics.RoleAssigned(plr: Player, role: string, rank: number, isFirstRound: boolean)
    custom(
        plr,
        "role_assigned",
        rank,
        fields(role, Analytics.Bucket(rank, RANK_EDGES), isFirstRound)
    )
end

function Analytics.PlayerDeath(
    plr: Player,
    role: string,
    killerRole: string,
    timeAlive: number,
    map: string,
    pos: Vector3
)
    -- Roblox rejects a custom field containing a comma, a quote or an
    -- apostrophe, and drops the whole event, so the cell reads 4x4 not 4,4
    local cell = Config.HEATMAP_CELL
    local cx, cz = math.floor((pos.X + 480) / cell), math.floor((pos.Z + 300) / cell)
    custom(
        plr,
        "player_death",
        math.floor(timeAlive),
        fields(role, killerRole, ("%s:%dx%d"):format(map, cx, cz))
    )
end

function Analytics.EvidenceExamined(
    plr: Player,
    clueCount: number,
    timeSinceDeath: number,
    rank: number
)
    custom(
        plr,
        "evidence_examined",
        math.floor(timeSinceDeath),
        fields(clueCount, Analytics.Bucket(rank, RANK_EDGES))
    )
end

function Analytics.CrateOpened(
    plr: Player,
    crateId: string,
    rarity: string,
    itemId: string,
    coinsAfter: number
)
    custom(plr, "crate_opened", coinsAfter, fields(crateId, rarity, itemId))
end

function Analytics.CoinsEarned(
    plr: Player,
    source: string,
    amount: number,
    balance: number,
    sessionTotal: number
)
    debugLog("coins_earned", source, amount, balance, sessionTotal)
    local transaction = Enum.AnalyticsEconomyTransactionType.Gameplay.Name
    if source == "streak" then
        transaction = Enum.AnalyticsEconomyTransactionType.TimedReward.Name
    elseif source == "robux" then
        transaction = Enum.AnalyticsEconomyTransactionType.IAP.Name
    end
    pcall(
        AnalyticsService.LogEconomyEvent,
        AnalyticsService,
        plr,
        Enum.AnalyticsEconomyFlowType.Source,
        "Coins",
        amount,
        balance,
        transaction,
        source,
        fields(Analytics.Bucket(sessionTotal, { 100, 250, 500, 1000, 2500 }))
    )
end

function Analytics.CoinsSpent(plr: Player, sink: string, amount: number, balanceAfter: number)
    debugLog("coins_spent", sink, amount, balanceAfter)
    pcall(
        AnalyticsService.LogEconomyEvent,
        AnalyticsService,
        plr,
        Enum.AnalyticsEconomyFlowType.Sink,
        "Coins",
        amount,
        balanceAfter,
        Enum.AnalyticsEconomyTransactionType.Shop.Name,
        sink
    )
end

function Analytics.TradeComplete(plr: Player, valueA: number, valueB: number)
    local lo, hi = math.min(valueA, valueB), math.max(valueA, valueB)
    local ratio = if lo > 0 then hi / lo else hi
    custom(
        plr,
        "trade_complete",
        math.floor(ratio * 100) / 100,
        fields(
            Analytics.Bucket(valueA, VALUE_EDGES),
            Analytics.Bucket(valueB, VALUE_EDGES),
            Analytics.Bucket(ratio, { 1.5, 3, 5, 10 })
        )
    )
end

function Analytics.SessionEnd(
    plr: Player,
    duration: number,
    roundsPlayed: number,
    coinsEarned: number,
    isNew: boolean
)
    custom(
        plr,
        "session_end",
        math.floor(duration),
        fields(
            Analytics.Bucket(roundsPlayed, { 1, 3, 5, 8, 12 }),
            Analytics.Bucket(coinsEarned, { 100, 250, 500, 1000 }),
            isNew
        )
    )
end

function Analytics.FirstSessionExit(
    plr: Player,
    lastScreen: string,
    secondsPlayed: number,
    roundsPlayed: number
)
    custom(
        plr,
        "first_session_exit",
        math.floor(secondsPlayed),
        fields(lastScreen, Analytics.Bucket(roundsPlayed, { 1, 2, 3, 5 }))
    )
end

-- Not one of the handbook's ten: SocialService reports. The reported player is
-- never a field (cardinality); the value is how many reports they have here.
function Analytics.PlayerReport(plr: Player, reason: string, reportsOnTarget: number)
    custom(
        plr,
        "player_report",
        reportsOnTarget,
        fields(reason, Analytics.Bucket(reportsOnTarget, { 2, 3, 5, 10 }))
    )
end

-- Onboarding funnel: each step logs once per player, in order
Analytics.FUNNEL = {
    JOINED = { 1, "joined" },
    VOTED = { 2, "voted" },
    FREE_CRATE = { 3, "free_crate" },
    FIRST_ROUND_START = { 4, "first_round_start" },
    FIRST_ROUND_END = { 5, "first_round_end" },
    SECOND_ROUND_START = { 6, "second_round_start" },
}

function Analytics.Funnel(plr: Player, step: { any })
    debugLog("funnel", step[1], step[2])
    pcall(AnalyticsService.LogOnboardingFunnelStepEvent, AnalyticsService, plr, step[1], step[2])
end

return Analytics
