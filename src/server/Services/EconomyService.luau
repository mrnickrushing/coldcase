local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local Shared = game.ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Rarities = require(Shared.RarityTable)
local Catalog = require(Shared.Catalog)
local LiveOps = require(Shared.LiveOps)
local Shop = require(Shared.Shop)
local Products = require(Shared.Products)
local Remotes = game.ReplicatedStorage.Remotes
local DataService = require(script.Parent.DataService)
local RoleService = require(script.Parent.RoleService)
local Analytics = require(script.Parent.Analytics)
local LiveOpsClock = require(script.Parent.LiveOpsClock)

local EconomyService = {}
local TIER_ORDER = { "Common", "Uncommon", "Rare", "Legendary", "Godly" }

-- Gameplay faucets that Last Call doubles: coins earned DURING the final
-- thirty seconds - a pickup, an examine, a revive. The end-of-round
-- settlement is deliberately not here; `round` was removed so a win pays the
-- same whether or not the round reached Last Call. Doubling the settlement
-- rewarded lasting longer rather than playing better, and since lastCallFired
-- resets each round it made identical wins pay 1.25x or 2.5x on round length
-- alone. Streaks, gifts and Robux purchases never multiply either.
local LAST_CALL_SOURCES = { pickup = true, examine = true, revive = true }
local lastCall = false

-- Pre-bucket the catalog by rarity so a pull is O(1). The Locker and crafting
-- never see seasonal or starter items; each season's crate only sees its own.
local standardPool = {}
local seasonPools = {}
for id, item in Catalog do
    if item.starter then
        continue
    end
    local pools = standardPool
    if item.season then
        seasonPools[item.season] = seasonPools[item.season] or {}
        pools = seasonPools[item.season]
    end
    pools[item.rarity] = pools[item.rarity] or {}
    table.insert(pools[item.rarity], id)
end
-- Deterministic order within each tier; table iteration order is not
for _, ids in standardPool do
    table.sort(ids)
end
for _, pools in seasonPools do
    for _, ids in pools do
        table.sort(ids)
    end
end

---------------------------------------------------------------- Friends
local friendsOf: { [Player]: { [Player]: boolean } } = {}

local function linkFriends(plr: Player)
    for _, other in Players:GetPlayers() do
        if other ~= plr then
            local ok, isFriend = pcall(plr.IsFriendsWithAsync, plr, other.UserId)
            if ok and isFriend and plr.Parent and other.Parent then
                friendsOf[plr] = friendsOf[plr] or {}
                friendsOf[other] = friendsOf[other] or {}
                friendsOf[plr][other] = true
                friendsOf[other][plr] = true
            end
        end
    end
end

function EconomyService:HasFriendInServer(plr: Player): boolean
    return next(friendsOf[plr] or {}) ~= nil
end

Players.PlayerAdded:Connect(linkFriends)
for _, plr in Players:GetPlayers() do
    task.spawn(linkFriends, plr)
end
Players.PlayerRemoving:Connect(function(plr)
    local friends = friendsOf[plr]
    if friends then
        for other in friends do
            if friendsOf[other] then
                friendsOf[other][plr] = nil
            end
        end
    end
    friendsOf[plr] = nil
end)

---------------------------------------------------------------- Items
-- The single place an item enters an inventory. Seasonal items only drop
-- while their season is open; a retired seasonal can never be minted again.
function EconomyService:GiveItem(data, id: string)
    local item = Catalog[id]
    if not item or item.starter then
        return nil
    end
    if item.season then
        local day = LiveOpsClock.Day()
        -- Two different questions: has this item's season closed for good, and
        -- is it the one running right now. The second alone would also block a
        -- season that has not opened yet, which is intended - but only the
        -- first is the "retired forever" rule, and it is the one under test.
        if LiveOps.IsRetired(item.season, day) then
            return nil
        end
        local season = LiveOps.ActiveSeason(day)
        if not season or season.id ~= item.season then
            return nil
        end
    end
    local entry = { id = id, uid = HttpService:GenerateGUID(false), at = os.time() }
    table.insert(data.inventory, entry)
    return entry
end

local function rollTier(pools)
    local total = 0
    for _, r in Rarities do
        if pools[r.name] then
            total += r.weight
        end
    end
    local n = math.random() * total
    for _, r in Rarities do
        if pools[r.name] then
            n -= r.weight
            if n <= 0 then
                return r
            end
        end
    end
    for _, r in Rarities do
        if pools[r.name] then
            return r
        end
    end
    return nil
end

local function giveRankGift(plr: Player, data)
    -- Grant first, then burn the once-per-account flag. The other way round,
    -- a refused GiveItem leaves rankGift true with nothing to show for it and
    -- the check at the call site never lets them have another go - the reward
    -- is gone for good. OnboardingService's free crate gets this right by
    -- un-setting its flag on failure; this simply does not set it early.
    local ids = standardPool[Config.RANK_GIFT_RARITY]
    local entry = EconomyService:GiveItem(data, ids[math.random(#ids)])
    if entry then
        data.onboarding.rankGift = true
        Remotes.CrateResult:FireClient(
            plr,
            { id = entry.id, uid = entry.uid, rarity = Config.RANK_GIFT_RARITY, gift = true }
        )
        Remotes.Notify:FireClient(
            plr,
            ("Rank %d gift · %s"):format(Config.RANK_GIFT_AT, Catalog[entry.id].name)
        )
    end
end

---------------------------------------------------------------- Coins + XP
function EconomyService:SetLastCall(on: boolean)
    lastCall = on
end

function EconomyService:CoinMultiplier(plr: Player, data, source: string): number
    local mult = LiveOps.CoinMultiplier(LiveOpsClock.Day())
    if self:HasFriendInServer(plr) then
        mult *= 1 + Config.FRIEND_COIN_BONUS
    end
    if data.passes.vip then
        mult *= Products.PASSES.vip.coinMultiplier
    end
    if lastCall and LAST_CALL_SOURCES[source] then
        mult *= Config.LAST_CALL_MULT
    end
    return mult
end

-- `source` names the faucet for analytics. `raw` grants skip every multiplier
-- (Robux purchases). Streak rewards are granted in DataService.
function EconomyService:Grant(
    plr: Player,
    coins: number?,
    xp: number?,
    source: string?,
    raw: boolean?
): number
    local data = DataService:Get(plr)
    if not data then
        return 0
    end
    local granted = 0
    if coins and coins > 0 then
        local mult = if raw then 1 else self:CoinMultiplier(plr, data, source or "unknown")
        granted = math.floor(coins * mult + 0.5)
        data.coins += granted
        local session = DataService:GetSession(plr)
        if session then
            session.coinsEarned += granted
        end
        Analytics.CoinsEarned(
            plr,
            source or "unknown",
            granted,
            data.coins,
            session and session.coinsEarned or 0
        )
    end

    data.xp += xp or 0
    local startRank = data.rank
    while data.xp >= Config.XP_PER_RANK do
        data.xp -= Config.XP_PER_RANK
        data.rank += 1
    end
    if data.rank ~= startRank then
        plr:SetAttribute("Rank", data.rank)
    end
    if data.rank >= Config.RANK_GIFT_AT and not data.onboarding.rankGift then
        giveRankGift(plr, data)
    end

    Remotes.DataChanged:FireClient(plr, { coins = data.coins, xp = data.xp, rank = data.rank })
    return granted
end

function EconomyService:PayOut(
    participants: { Player },
    winner: string,
    survivors: { [Player]: boolean },
    clueCounts
)
    local Participant = require(script.Parent.Participant)
    local withBots = false
    for _, p in participants do
        withBots = withBots or Participant.IsBot(p)
    end
    for _, plr in participants do
        local data = DataService:Get(plr)
        if not data then
            continue
        end

        local role = RoleService:Get(plr)
        local won = ((role == "murderer") and "murderer" or "innocents") == winner

        local coins = won and Config.COINS_WIN or Config.COINS_LOSS
        local xp = won and Config.XP_WIN or Config.XP_LOSS
        if survivors[plr] then
            coins += Config.COINS_SURVIVE
            xp += Config.XP_SURVIVE
        end
        local clues = clueCounts[plr] or 0
        xp += clues * Config.XP_PER_CLUE

        data.stats.rounds += 1
        if won then
            data.stats.wins += 1
            if role == "murderer" then
                data.stats.murdererWins += 1
            end
        end
        local session = DataService:GetSession(plr)
        if session then
            session.rounds += 1
        end

        if withBots then
            -- The lever for paying less in a round against NPCs, so an empty
            -- server cannot be farmed. It is set to 1 - full pay - because a
            -- solo player's first rounds are all NPC rounds and docking them
            -- punishes the newest players hardest. Left in place so the nerf
            -- is one number away if farming ever shows up in the numbers.
            coins = math.floor(coins * Config.BOT_ROUND_REWARD)
            xp = math.floor(xp * Config.BOT_ROUND_REWARD)
        end
        local granted = self:Grant(plr, coins, xp, "round")
        -- Near-miss messaging: honest, and shown only when they cannot afford a crate
        local cratePrice = Shop.CratePrice(Config.CRATE_COST, data.rank)
        Remotes.RoundReward:FireClient(plr, {
            won = won,
            coins = granted,
            xp = xp,
            clues = clues,
            balance = data.coins,
            short = math.max(0, cratePrice - data.coins),
        })
    end
end

---------------------------------------------------------------- Crates
function EconomyService:OpenCrate(plr: Player, crateId: any, free: boolean?)
    if crateId ~= "locker" and crateId ~= "seasonal" then
        return nil
    end
    local data = DataService:Get(plr)
    if not data then
        return nil
    end
    -- Paid random items are restricted in some regions (PolicyService).
    -- The one free onboarding crate is not a paid item.
    if not free and not require(script.Parent.PlayerPolicy):CanUsePaidRandomItems(plr) then
        Remotes.ShopResult:FireClient(plr, false, "Crates aren't available in your region.")
        return nil
    end

    local pools, cost, usesKey = nil, 0, false
    if crateId == "seasonal" then
        local season = LiveOps.ActiveSeason(LiveOpsClock.Day())
        if not season then
            return nil
        end
        pools = seasonPools[season.id]
        cost = Shop.CratePrice(season.crateCost, data.rank)
        -- A seasonal key (Robux) opens the crate instead of coins
        if not free and data.seasonalKeys > 0 then
            usesKey, cost = true, 0
        end
    else
        pools, cost = standardPool, Shop.CratePrice(Config.CRATE_COST, data.rank)
    end
    if not pools then
        return nil
    end
    if free then
        cost = 0
    end
    if data.coins < cost then
        Remotes.ShopResult:FireClient(
            plr,
            false,
            ("You are %d coins short."):format(cost - data.coins)
        )
        return nil
    end

    -- Roll the tier FIRST, then draw a name from that tier.
    local tier = rollTier(pools)
    if not tier then
        return nil
    end
    local ids = pools[tier.name]
    local entry = self:GiveItem(data, ids[math.random(#ids)])
    if not entry then
        return nil
    end
    data.coins -= cost
    if usesKey then
        data.seasonalKeys -= 1
    end

    Analytics.CrateOpened(plr, crateId, tier.name, entry.id, data.coins)
    if cost > 0 then
        Analytics.CoinsSpent(plr, crateId, cost, data.coins)
    end
    Remotes.CrateResult:FireClient(plr, {
        id = entry.id,
        uid = entry.uid,
        rarity = tier.name,
        crateId = crateId,
        free = free == true,
    })
    Remotes.DataChanged:FireClient(
        plr,
        { coins = data.coins, inventory = data.inventory, seasonalKeys = data.seasonalKeys }
    )

    if tier.announce then
        -- Other players seeing a big drop is the cheapest crate advert there is
        Remotes.CrateResult:FireAllClients({
            announce = true,
            player = plr.DisplayName,
            item = Catalog[entry.id].name,
            rarity = tier.name,
        })
    end
    return entry
end

function EconomyService:Craft(plr: Player, itemId: any)
    if type(itemId) ~= "string" or not Catalog[itemId] then
        return
    end
    local data = DataService:Get(plr)
    if not data then
        return
    end
    -- Crafting pays coins for a random next-tier item: a paid random item
    if not require(script.Parent.PlayerPolicy):CanUsePaidRandomItems(plr) then
        Remotes.ShopResult:FireClient(plr, false, "Crafting isn't available in your region.")
        return
    end
    local matches = {}
    for i, item in data.inventory do
        if item.id == itemId then
            table.insert(matches, i)
        end
    end
    if #matches < Config.CRAFT_DUPES then
        Remotes.ShopResult:FireClient(
            plr,
            false,
            ("Crafting needs %d of the same item."):format(Config.CRAFT_DUPES)
        )
        return
    end
    if data.coins < Config.CRAFT_FEE then
        Remotes.ShopResult:FireClient(
            plr,
            false,
            ("You are %d coins short."):format(Config.CRAFT_FEE - data.coins)
        )
        return
    end

    local nextTier
    for i, r in TIER_ORDER do
        if r == Catalog[itemId].rarity then
            nextTier = TIER_ORDER[i + 1]
        end
    end
    local pool = nextTier and standardPool[nextTier]
    if not pool then
        Remotes.ShopResult:FireClient(plr, false, "Nothing ranks above Godly.")
        return
    end

    -- Grant first, charge second. GiveItem can refuse (a starter, or a
    -- seasonal whose season has closed), and the old order took the fee and
    -- the five duplicates before finding out - leaving the player with
    -- nothing for 150 coins and five items. OpenCrate already works this way.
    local entry = self:GiveItem(data, pool[math.random(#pool)])
    if not entry then
        Remotes.ShopResult:FireClient(plr, false, "That craft is not available right now.")
        return
    end

    -- `matches` are indices taken before the grant. GiveItem appends, which
    -- shifts nothing already in the list, and removing high indices first
    -- keeps the rest valid - but neither of those is obvious, so remove by
    -- identity instead of trusting the arithmetic to stay true.
    local doomed = {}
    for i = 1, Config.CRAFT_DUPES do
        doomed[data.inventory[matches[i]]] = true
    end
    for i = #data.inventory, 1, -1 do
        if doomed[data.inventory[i]] then
            table.remove(data.inventory, i)
        end
    end

    data.coins -= Config.CRAFT_FEE
    Analytics.CoinsSpent(plr, "craft", Config.CRAFT_FEE, data.coins)
    Remotes.CrateResult:FireClient(
        plr,
        { id = entry.id, uid = entry.uid, rarity = nextTier, crafted = true }
    )
    require(script.Parent.CosmeticService):Reconcile(plr)
    Remotes.DataChanged:FireClient(plr, { coins = data.coins, inventory = data.inventory })
end

return EconomyService
