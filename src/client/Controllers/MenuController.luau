-- StarterPlayerScripts/Controllers/MenuController
-- Drives LobbyGui, ResultsGui, CrateGui and InventoryGui (TradeController
-- owns TradeGui). Builds every menu at runtime.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Theme = require(Shared.Theme)
local Catalog = require(Shared.Catalog)
local Rarities = require(Shared.RarityTable)
local Shop = require(Shared.Shop)
local Progression = require(Shared.Progression)
local Lobby = require(Shared.Lobby)
local LiveOps = require(Shared.LiveOps)
local Products = require(Shared.Products)
local BuildMenus = require(Shared.Build.BuildMenus)
local ItemCard = require(Shared.Build.ItemCard)
local ClientState = require(script.Parent.Parent.ClientState)

local plr = Players.LocalPlayer
local pg = plr:WaitForChild("PlayerGui")
local guis = BuildMenus(pg)
local lobby = guis.lobby.Root
local results = guis.results.Root
local crate = guis.crate.Root
local inv = guis.inventory.Root
local MenuController = {}

local RARITY_COLOUR = ItemCard.RARITY_COLOUR
local GREEN = Color3.fromHex("4fb0a0")
local QUIET_STROKE = Color3.fromHex("1f252e")
local RAISED = Color3.fromHex("161b22")
local current: string? = nil

local function data()
    return ClientState.data
end

local function setEnabled(b: TextButton, on: boolean)
    b.AutoButtonColor = on
    b.BackgroundTransparency = on and 0 or 0.5
    b.TextTransparency = on and 0 or 0.45
end

local function show(name: string?)
    current = name
    for key, g in guis do
        g.Enabled = key == name
    end
    ClientState.Set("screen", name)
end
ClientState.ShowScreen = show

local function mmss(t: number): string
    t = math.floor(t)
    return ("%d:%02d"):format(t // 60, t % 60)
end

---------------------------------------------------------------- Lobby
local myVote: string? = nil
local tally: { [string]: number } = {}

local function renderVotes()
    local total = 0
    for _, n in tally do
        total += n
    end
    local open = ClientState.GetRoundState() == "INTERMISSION"
    for i, mapName in Config.MAPS do
        local card = lobby.Maps["Map" .. i]
        local n = tally[mapName] or 0
        card.Body.Votes.Text = tostring(n)
        card.Body.BarBg.Bar.Size = UDim2.fromScale(total > 0 and n / total or 0, 1)
        card.Stroke.Color = mapName == myVote and Theme.AMBER or QUIET_STROKE
        local vote = card.Body.Vote
        vote.Text = if not open then "CLOSED" elseif mapName == myVote then "VOTED" else "VOTE"
        setEnabled(vote, open)
    end
end

for i, mapName in Config.MAPS do
    lobby.Maps["Map" .. i].Body.Vote.Activated:Connect(function()
        if ClientState.GetRoundState() ~= "INTERMISSION" then
            return
        end
        myVote = mapName
        Remotes.RequestVote:FireServer(mapName)
        renderVotes()
    end)
end
Remotes.VoteTally.OnClientEvent:Connect(function(t)
    tally = t
    renderVotes()
end)

local reported: { [number]: boolean } = {} -- UserIds this client has reported

local function renderPlayers()
    local listFrame = lobby.Players.List
    local template = listFrame.RowTemplate
    for _, c in listFrame:GetChildren() do
        if c:IsA("Frame") and c ~= template then
            c:Destroy()
        end
    end
    local tradingOpen = ReplicatedStorage:GetAttribute("TradingOpen") == true
    local opensDay = ReplicatedStorage:GetAttribute("TradingOpensDay") or LiveOps.TRADING_UNLOCK_DAY
    local everyone = Players:GetPlayers()
    table.sort(everyone, function(a, b)
        return (a:GetAttribute("Rank") or 1) > (b:GetAttribute("Rank") or 1)
    end)
    for i, other in everyone do
        local row = template:Clone()
        row.Name = tostring(other.UserId)
        row.Visible = true
        row.LayoutOrder = i
        local rank = other:GetAttribute("Rank") or 1
        row.PlayerName.Text = other == plr and (other.DisplayName .. " (you)") or other.DisplayName
        row.Rank.Text = if other:GetAttribute("WaitForPlayers") == true
            then ("RANK %d · WAITING"):format(rank)
            else ("RANK %d · %s"):format(rank, string.upper(Progression.TitleFor(rank)))
        row.Trade.Visible = other ~= plr
        -- PolicyService: paid item trading is not allowed in some regions
        local canTrade = tradingOpen and plr:GetAttribute("PaidItemTradingAllowed") == true
        row.Trade.Text = if not tradingOpen
            then ("DAY %d"):format(opensDay)
            elseif canTrade then "TRADE"
            else "N/A"
        setEnabled(row.Trade, canTrade)
        row.Trade.Activated:Connect(function()
            if ReplicatedStorage:GetAttribute("TradingOpen") and other.Parent then
                Remotes.RequestTrade:FireServer("open", other)
                row.Trade.Text = "ASKED"
            end
        end)

        row.Report.Visible = other ~= plr
        row.Report.Text = reported[other.UserId] and "REPORTED" or "REPORT"
        setEnabled(row.Report, not reported[other.UserId])
        local armed = false
        row.Report.Activated:Connect(function()
            if reported[other.UserId] or other.Parent ~= Players then
                return
            end
            if not armed then
                -- One tap arms it, a second sends: a report is never an accident
                armed = true
                row.Report.Text = "CHEATING?"
                task.delay(3, function()
                    if armed and not reported[other.UserId] then
                        armed = false
                        row.Report.Text = "REPORT"
                    end
                end)
                return
            end
            reported[other.UserId] = true
            Remotes.RequestReport:FireServer(other, "exploiting")
            row.Report.Text = "REPORTED"
            setEnabled(row.Report, false)
        end)
        row.Parent = listFrame
    end
end

local function watchPlayer(other: Player)
    other:GetAttributeChangedSignal("Rank"):Connect(renderPlayers)
    other:GetAttributeChangedSignal("WaitForPlayers"):Connect(renderPlayers)
end
Players.PlayerAdded:Connect(function(other)
    watchPlayer(other)
    renderPlayers()
end)
Players.PlayerRemoving:Connect(function()
    task.defer(renderPlayers)
end)
for _, other in Players:GetPlayers() do
    watchPlayer(other)
end
ReplicatedStorage:GetAttributeChangedSignal("TradingOpen"):Connect(renderPlayers)

local STORE = {
    vip = { def = Products.PASSES.vip, pass = true },
    radio = { def = Products.PASSES.radio, pass = true },
    emotes = { def = Products.PASSES.emotes, pass = true },
    coins2500 = { def = Products.PRODUCTS.coins2500 },
    seasonalKey = { def = Products.PRODUCTS.seasonalKey },
}

local function renderSide()
    local d = data()
    local side = lobby.Side
    local rank = d.rank or 1
    local coins = d.coins or 0
    side.Rank.Text = ("%d · %s"):format(rank, string.upper(Progression.TitleFor(rank)))
    side.XpBg.Xp.Size = UDim2.fromScale(math.clamp((d.xp or 0) / Config.XP_PER_RANK, 0, 1), 1)
    side.XpText.Text = ("%d / %d XP"):format(d.xp or 0, Config.XP_PER_RANK)
    side.Coins.Text = ("%d COINS"):format(coins)
    side.Keys.Text = (d.seasonalKeys or 0) > 0 and ("SEASONAL KEYS · %d"):format(d.seasonalKeys)
        or ""

    -- The gap between what they have and what they want, legible from round two
    local price = Shop.CratePrice(Config.CRATE_COST, rank)
    side.Buttons.OpenCrate.Text = coins >= price and ("CRATE · %d"):format(price)
        or ("CRATE · %d/%d"):format(coins, price)

    for key, entry in STORE do
        local b = lobby.Store[key]
        local def = entry.def
        -- A key only opens a random crate, so it is not offered where those are restricted
        local restricted = key == "seasonalKey"
            and plr:GetAttribute("PaidRandomItemsRestricted") ~= false
        b.Visible = def.id ~= 0 and not restricted
        local owned = entry.pass and d.passes and d.passes[key]
        b.Text = owned and (string.upper(def.name) .. " · OWNED")
            or ("%s · %d R$"):format(string.upper(def.name), def.price)
        setEnabled(b, not owned)
    end
end

for key, entry in STORE do
    lobby.Store[key].Activated:Connect(function()
        local def = entry.def
        if def.id == 0 then
            return
        end
        if entry.pass then
            if not (data().passes and data().passes[key]) then
                MarketplaceService:PromptGamePassPurchase(plr, def.id)
            end
        else
            MarketplaceService:PromptProductPurchase(plr, def.id)
        end
    end)
end

-- Play now with NPCs, or wait for a round of real players. Saved to the profile.
local waiting = plr:GetAttribute("WaitForPlayers") == true

local function renderMode()
    local mode = lobby.Header.Mode
    for _, entry in { { mode.PlayNow, not waiting }, { mode.Wait, waiting } } do
        local b, on = entry[1], entry[2]
        b.BackgroundColor3 = if on then Theme.AMBER else RAISED
        b.TextColor3 = if on then Theme.GROUND else Theme.SOFT
        b.Stroke.Color = if on then Theme.AMBER else QUIET_STROKE
    end
end

local function choose(wait: boolean)
    if wait == waiting then
        return
    end
    waiting = wait
    renderMode()
    Remotes.RequestLobbyMode:FireServer(if wait then "wait" else "play")
end
lobby.Header.Mode.PlayNow.Activated:Connect(function()
    choose(false)
end)
lobby.Header.Mode.Wait.Activated:Connect(function()
    choose(true)
end)
plr:GetAttributeChangedSignal("WaitForPlayers"):Connect(function()
    waiting = plr:GetAttribute("WaitForPlayers") == true
    renderMode()
end)
renderMode()

local countdownAccum = 0
RunService.Heartbeat:Connect(function(dt)
    countdownAccum += dt
    if countdownAccum < 0.25 or current ~= "lobby" then
        return
    end
    countdownAccum = 0
    local left = math.max(
        0,
        math.ceil((ReplicatedStorage:GetAttribute("RoundEnds") or 0) - workspace:GetServerTimeNow())
    )
    local everyone = Players:GetPlayers()
    local ready = 0
    for _, other in everyone do
        local waits = if other == plr then waiting else other:GetAttribute("WaitForPlayers") == true
        if not waits then
            ready += 1
        end
    end
    -- Mirrors RoundService, which decides with the same Lobby.Plan
    local plan =
        Lobby.Plan(#everyone, ready, Config.MIN_PLAYERS, Config.BOT_FILL_TO, Config.BOTS_ENABLED)
    local label
    if ClientState.GetRoundState() ~= "INTERMISSION" then
        label = ("ROUND IN PROGRESS · %ds"):format(left)
    elseif plan.full then
        label = ("STARTS IN %ds"):format(left)
    elseif plan.start and not waiting then
        label = ("STARTS IN %ds · %d NPCS JOIN"):format(left, plan.npcs)
    else
        label = ("WAITING FOR PLAYERS · %d/%d"):format(#everyone, Config.MIN_PLAYERS)
    end
    lobby.Header.Countdown.Text = label
end)

---------------------------------------------------------------- Loading
-- The scene's name and a bar across the LOADING window, so the map swap reads
-- as a beat of the game rather than a stall with a bare HUD
local loading = guis.loading.Root

local function renderLoadingName()
    local mapName = ReplicatedStorage:GetAttribute("RoundMap")
    loading.MapName.Text = if type(mapName) == "string"
        then string.upper((mapName:gsub("(%l)(%u)", "%1 %2")))
        else ""
end
ReplicatedStorage:GetAttributeChangedSignal("RoundMap"):Connect(renderLoadingName)
renderLoadingName()

RunService.Heartbeat:Connect(function()
    if current ~= "loading" then
        return
    end
    local left = (ReplicatedStorage:GetAttribute("RoundEnds") or 0) - workspace:GetServerTimeNow()
    local done = math.clamp(1 - left / Config.LOADING_TIME, 0, 1)
    loading.BarBg.Bar.Size = UDim2.fromScale(done, 1)
end)

---------------------------------------------------------------- Results
local BLURB = {
    killed = "The murderer is down. Everyone still standing walks out.",
    wiped = "No one left to tell it. The murderer walks.",
    time = "Time ran out. The survivors make it to dawn.",
    left = "The murderer bolted. Case closed, nobody caught.",
}
local lastReward = nil
local pendingResults = false

-- KillCamController holds the screen for a few seconds before the verdict
ClientState.On("killcam", function(on)
    if not on and pendingResults then
        pendingResults = false
        show("results")
    end
end)

local function renderReward()
    local r = lastReward
    local rw = results.Lower.Rewards
    rw.Xp.Value.Text = r and ("+%d"):format(r.xp) or "—"
    rw.Coins.Value.Text = r and ("+%d"):format(r.coins) or "—"
    rw.Clues.Value.Text = r and tostring(r.clues or 0) or "—"
    -- Near-miss messaging: honest, and only when they cannot afford a crate
    results.Lower.NearMiss.Text = (r and r.short > 0)
            and ("You were %d coins short."):format(r.short)
        or ""
end

Remotes.RoundReward.OnClientEvent:Connect(function(reward)
    lastReward = reward
    renderReward()
end)

Remotes.RoundOver.OnClientEvent:Connect(function(winner: string, reason: string, reveal, timeline)
    reveal = reveal or {}
    timeline = timeline or {}

    local banner = results.Banner
    local role = ClientState.role
    if role then
        local won = ((role == "murderer") and "murderer" or "innocents") == winner
        banner.BackgroundColor3 = won and Theme.AMBER or Theme.DANGER
        banner.Title.Text = won and "YOU WON" or "YOU LOST"
        banner.Title.TextColor3 = Theme.GROUND
    else
        banner.BackgroundColor3 = Theme.STROKE
        banner.Title.Text = winner == "murderer" and "THE MURDERER WINS" or "THE INNOCENTS WIN"
        banner.Title.TextColor3 = Theme.INK
    end

    local murderers, isMurderer = {}, {}
    for name, r in reveal do
        if r == "murderer" then
            table.insert(murderers, name)
            isMurderer[name] = true
        end
    end
    table.sort(murderers)

    local dead, kills = {}, 0
    for _, e in timeline do
        if e.method == "revived" then
            dead[e.victim] = nil
        else
            dead[e.victim] = true
            if e.killer and isMurderer[e.killer] then
                kills += 1
            end
        end
    end

    local rv = results.Reveal
    rv.KillerName.Text = #murderers > 0 and string.upper(table.concat(murderers, " & ")) or "—"
    rv.KillerTally.Text = ("%s · %d eliminated"):format(
        #murderers > 1 and "were the murderers" or "was the murderer",
        kills
    )

    for _, c in rv.Roster:GetChildren() do
        if c:IsA("Frame") then
            c:Destroy()
        end
    end
    local names = {}
    for name in reveal do
        table.insert(names, name)
    end
    table.sort(names)
    for i, name in names do
        local r = reveal[name]
        local chip = Instance.new("Frame")
        chip.LayoutOrder = i
        chip.BackgroundColor3 = Theme.PANEL
        chip.BorderSizePixel = 0
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 4)
        corner.Parent = chip
        local s = Instance.new("UIStroke")
        s.Color = r == "murderer" and Theme.DANGER or QUIET_STROKE
        s.Parent = chip
        local l = Instance.new("TextLabel")
        l.RichText = true
        local label = ("%s  %s"):format(name, string.upper(r))
        l.Text = dead[name] and ("<s>" .. label .. "</s>") or label
        l.FontFace = Theme.MONO
        l.TextSize = 10
        l.TextColor3 = Theme.ROLE[r] or Theme.BODY
        l.TextTransparency = dead[name] and 0.4 or 0
        l.BackgroundTransparency = 1
        l.Size = UDim2.fromScale(1, 1)
        l.Parent = chip
        chip.Parent = rv.Roster
    end

    local lower = results.Lower
    lower.Blurb.Text = BLURB[reason] or ""
    local tlList = lower.Timeline.List
    for _, c in tlList:GetChildren() do
        if c:IsA("TextLabel") then
            c:Destroy()
        end
    end
    local lines = {}
    for _, e in timeline do
        if e.method == "revived" then
            table.insert(lines, ("%s  %s was revived"):format(mmss(e.at), e.victim))
        else
            table.insert(
                lines,
                ("%s  %s eliminated %s"):format(mmss(e.at), e.killer or "?", e.victim)
            )
        end
    end
    if #lines == 0 then
        lines = { "No one died." }
    end
    for i = math.max(1, #lines - 3), #lines do
        local l = Instance.new("TextLabel")
        l.LayoutOrder = i
        l.Text = lines[i]
        l.FontFace = Theme.MONO
        l.TextSize = 12
        l.TextColor3 = Theme.BODY
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.BackgroundTransparency = 1
        l.Size = UDim2.new(1, 0, 0, 16)
        l.Parent = tlList
    end

    renderReward()
    task.defer(function()
        if ClientState.killcam then
            pendingResults = true
        else
            show("results")
        end
    end)
end)

---------------------------------------------------------------- Crate
local CARD_W, CARD_GAP, WIN_INDEX, REEL_CARDS = 132, 12, 28, 34
local crateId = "locker"
local spinning, reelRunning, spinToken = false, false, 0

local function seasonOpen(): boolean
    return ReplicatedStorage:GetAttribute("SeasonId") ~= nil
end

-- Client mirror of the server's pools: starters never drop, seasonals only
-- from their own crate
local function poolIds(id: string): { string }
    local season = ReplicatedStorage:GetAttribute("SeasonId")
    local out = {}
    for cid, item in Catalog do
        if item.starter then
            continue
        end
        if
            (id == "seasonal" and item.season ~= nil and item.season == season)
            or (id ~= "seasonal" and not item.season)
        then
            table.insert(out, cid)
        end
    end
    table.sort(out)
    return out
end

local function renderOdds()
    local present = {}
    for _, id in poolIds(crateId) do
        present[Catalog[id].rarity] = true
    end
    local total = 0
    for _, r in Rarities do
        if present[r.name] then
            total += r.weight
        end
    end
    for _, r in Rarities do
        local row = crate.Odds.List[r.name]
        local pct = (present[r.name] and total > 0) and (r.weight / total * 100) or 0
        row.Visible = present[r.name] == true
        row.Pct.Text = (math.floor(pct) == pct) and ("%d%%"):format(pct) or ("%.1f%%"):format(pct)
        row.BarBg.Bar.Size = UDim2.fromScale(pct / 100, 1)
    end
end

local function renderCrate(): boolean
    if crateId == "seasonal" and not seasonOpen() then
        crateId = "locker"
    end
    local d = data()
    local coins = d.coins or 0
    local seasonName = ReplicatedStorage:GetAttribute("SeasonName") or "Seasonal"
    local header = crate.Header

    header.Title.Text = crateId == "seasonal" and string.upper(seasonName) or "THE LOCKER"
    header.Tabs.Seasonal.Visible = seasonOpen()
    header.Tabs.Seasonal.Text = string.upper(seasonName)
    for _, key in { "Locker", "Seasonal" } do
        local selected = string.lower(key) == crateId
        header.Tabs[key].Stroke.Color = selected and Theme.AMBER or Color3.fromHex("2b323c")
        header.Tabs[key].TextColor3 = selected and Theme.AMBER or Theme.MUTED
    end
    local daysLeft = ReplicatedStorage:GetAttribute("SeasonDaysLeft")
    header.Countdown.Text = (seasonOpen() and daysLeft)
            and ("%s RETIRES FOREVER IN %d DAYS"):format(string.upper(seasonName), daysLeft)
        or ""
    crate.Odds.Caption.Text = "PUBLISHED ODDS · " .. header.Title.Text
    renderOdds()

    local base = crateId == "seasonal"
            and (ReplicatedStorage:GetAttribute("SeasonCrateCost") or Config.SEASONAL_COST)
        or Config.CRATE_COST
    local price = Shop.CratePrice(base, d.rank or 1)
    local keys = d.seasonalKeys or 0
    local spin = crate.Buttons.Spin
    local canSpin = false
    if spinning then
        spin.Text = "ROLLING…"
    elseif plr:GetAttribute("PaidRandomItemsRestricted") ~= false then
        -- Unset while the server's policy lookup is pending; the server fails closed too
        spin.Text = "NOT AVAILABLE IN YOUR REGION"
    elseif crateId == "seasonal" and keys > 0 then
        spin.Text = ("SPIN · USE KEY (%d)"):format(keys)
        canSpin = true
    elseif coins >= price then
        spin.Text = ("SPIN · %d COINS"):format(price)
        canSpin = true
    else
        spin.Text = ("NEED %d MORE"):format(price - coins)
    end
    setEnabled(spin, canSpin)
    crate.Buttons.Balance.Text = ("%d coins"):format(coins)

    for _, card in crate.Shelf.Items:GetChildren() do
        local id = card:GetAttribute("ItemId")
        if id then
            local p = Shop.PriceOf(id) :: number
            card.Price.Text = ("BUY · %d"):format(p)
            card.Price.TextColor3 = coins >= p and Theme.AMBER or Theme.DIM
        end
    end
    return canSpin
end

local function crateMessage(message: string, colour: Color3)
    crate.WonText.Text = message
    crate.WonText.TextColor3 = colour
end

for i, id in Shop.SHELF do
    local card = ItemCard.new(crate.Shelf.Items, id, nil, true)
    card.LayoutOrder = i
    card:SetAttribute("ItemId", id)
    local price = Instance.new("TextLabel")
    price.Name = "Price"
    price.FontFace = Theme.MONO
    price.TextScaled = true
    price.BackgroundTransparency = 1
    price.Position = UDim2.fromScale(0.05, 0.87)
    price.Size = UDim2.fromScale(0.9, 0.1)
    price.Parent = card
    card.Button.Activated:Connect(function()
        local p = Shop.PriceOf(id) :: number
        if (data().coins or 0) >= p then
            Remotes.RequestBuy:FireServer(id)
        else
            crateMessage(("You are %d coins short."):format(p - (data().coins or 0)), Theme.DANGER)
        end
    end)
end

local function spinReel(res)
    local reel = crate.ReelBox.Reel
    for _, c in reel:GetChildren() do
        if c:IsA("Frame") then
            c:Destroy()
        end
    end
    local ids = poolIds(res.crateId or "locker")
    if #ids == 0 then
        ids = { res.id }
    end
    -- Decoys, with the item the server actually granted at WIN_INDEX
    for i = 1, REEL_CARDS do
        local id = (i == WIN_INDEX) and res.id or ids[math.random(#ids)]
        ItemCard.new(reel, id, UDim2.fromOffset(CARD_W, 150)).LayoutOrder = i
    end
    reel.Position = UDim2.new(0, 12, 0, 16)
    crateMessage("ROLLING…", Theme.DIM)
    reelRunning, spinning = true, true
    renderCrate()

    task.wait() -- let layout settle so the box width is real
    local scale = math.max(crate.Scale.Scale, 0.01)
    local boxWidth = crate.ReelBox.AbsoluteSize.X / scale
    if boxWidth <= 0 then
        boxWidth = 988
    end
    local winCentre = 12 + (WIN_INDEX - 1) * (CARD_W + CARD_GAP) + CARD_W / 2
    local jitter = math.random(-46, 46)
    local tween = TweenService:Create(
        reel,
        TweenInfo.new(5.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
        { Position = UDim2.new(0, boxWidth / 2 - winCentre + jitter, 0, 16) }
    )
    tween:Play()
    tween.Completed:Wait()

    local def = Catalog[res.id]
    crateMessage(
        ("%s · %s"):format(string.upper(def and def.name or "?"), string.upper(res.rarity)),
        RARITY_COLOUR[res.rarity] or Theme.INK
    )
    reelRunning, spinning = false, false
    renderCrate()
end

Remotes.CrateResult.OnClientEvent:Connect(function(res)
    if res.announce or res.gift or res.crafted then
        return -- NoticeController toasts these
    end
    local st = ClientState.GetRoundState()
    if ClientState.role and st ~= "INTERMISSION" and st ~= "RESOLUTION" then
        return -- never pull a participant out of a live round
    end
    crateId = res.crateId or "locker"
    show("crate")
    task.spawn(spinReel, res)
end)

crate.Buttons.Spin.Activated:Connect(function()
    if spinning or not renderCrate() then
        return
    end
    spinning = true
    spinToken += 1
    local mine = spinToken
    Remotes.RequestCrate:FireServer(crateId)
    renderCrate()
    -- The server rejects silently in some cases; do not leave the button stuck
    task.delay(4, function()
        if spinToken == mine and spinning and not reelRunning then
            spinning = false
            renderCrate()
        end
    end)
end)

crate.Header.Tabs.Locker.Activated:Connect(function()
    if not spinning then
        crateId = "locker"
        renderCrate()
    end
end)
crate.Header.Tabs.Seasonal.Activated:Connect(function()
    if not spinning and seasonOpen() then
        crateId = "seasonal"
        renderCrate()
    end
end)
crate.Buttons.Close.Activated:Connect(function()
    show("lobby")
end)
for _, attr in { "SeasonId", "SeasonDaysLeft", "SeasonCrateCost" } do
    ReplicatedStorage:GetAttributeChangedSignal(attr):Connect(function()
        if current == "crate" then
            renderCrate()
        end
    end)
end

---------------------------------------------------------------- Inventory
local selected: string? = nil
local renderedInventory, renderedEquipped = nil, nil

-- Starters are owned by everyone and live outside the saved inventory
local function entries()
    local out = { { uid = "ash", id = "ash" }, { uid = "ledger", id = "ledger" } }
    for _, item in data().inventory or {} do
        table.insert(out, item)
    end
    return out
end

local function countOf(id: string): number
    local n = 0
    for _, item in data().inventory or {} do
        if item.id == id then
            n += 1
        end
    end
    return n
end

local function selectedEntry()
    for _, e in entries() do
        if e.uid == selected then
            return e
        end
    end
    return nil
end

local function renderInventoryButtons()
    local e = selectedEntry()
    local def = e and Catalog[e.id]
    local craft, reroll = inv.Buttons.Craft, inv.Buttons.Reroll
    if plr:GetAttribute("PaidRandomItemsRestricted") ~= false then
        -- Both hand out random results for coins; restricted in some regions
        craft.Text = "CRAFTING NOT AVAILABLE"
        reroll.Text = "RE-ROLL NOT AVAILABLE"
        setEnabled(craft, false)
        setEnabled(reroll, false)
        return
    end
    if def and not def.starter then
        local n = countOf(e.id)
        local ready = n >= Config.CRAFT_DUPES
        craft.Text = ready and ("CRAFT %d → 1 · %d"):format(Config.CRAFT_DUPES, Config.CRAFT_FEE)
            or ("CRAFT · %d/%d %s"):format(n, Config.CRAFT_DUPES, string.upper(def.name))
        setEnabled(craft, ready)
    else
        craft.Text = ("CRAFT %d → 1"):format(Config.CRAFT_DUPES)
        setEnabled(craft, false)
    end
    local isKnife = def ~= nil and def.kind == "Knife" and not def.starter
    reroll.Text = isKnife and ("RE-ROLL EFFECT · %d"):format(Config.REROLL_COST)
        or "RE-ROLL EFFECT"
    setEnabled(reroll, isKnife)
end

local function renderInventory()
    local d = data()
    renderedInventory, renderedEquipped = d.inventory, d.equipped
    local scroll = inv.Items
    local template = scroll.ItemTemplate
    for _, c in scroll:GetChildren() do
        if c:IsA("Frame") and c ~= template then
            c:Destroy()
        end
    end
    inv.Summary.Text = ("%d owned · %d coins"):format(#(d.inventory or {}), d.coins or 0)

    for i, e in entries() do
        local def = Catalog[e.id]
        if not def then
            continue
        end
        local card = template:Clone()
        card.Name = e.uid
        card.Visible = true
        card.LayoutOrder = i
        local colour = RARITY_COLOUR[def.rarity] or Theme.DIM
        card.Swatch.BackgroundColor3 = colour
        card.ItemName.Text = def.name
        card.Rarity.Text = ("%s · %s"):format(
            def.starter and "STARTER" or string.upper(def.rarity),
            string.upper(def.kind)
        )
        card.Rarity.TextColor3 = colour
        card.Effect.Text = (def.kind == "Knife" and not def.starter)
                and ("EFFECT · %s"):format(string.upper(e.effect or "none"))
            or ""
        local slot = Shop.SLOT_FOR_KIND[def.kind]
        local equipped = d.equipped ~= nil and slot ~= nil and d.equipped[slot] == e.id
        card.Equip.Text = equipped and "EQUIPPED" or "EQUIP"
        setEnabled(card.Equip, not equipped)
        card.Stroke.Color = e.uid == selected and Theme.INK or QUIET_STROKE
        card.Select.Activated:Connect(function()
            selected = e.uid
            renderInventory()
        end)
        card.Equip.Activated:Connect(function()
            selected = e.uid
            Remotes.RequestEquip:FireServer(e.uid)
        end)
        card.Parent = scroll
    end
    renderInventoryButtons()
end

inv.Buttons.Craft.Activated:Connect(function()
    local e = selectedEntry()
    if e and not Catalog[e.id].starter then
        Remotes.RequestCraft:FireServer(e.id)
    end
end)
inv.Buttons.Reroll.Activated:Connect(function()
    local e = selectedEntry()
    if e and not Catalog[e.id].starter then
        Remotes.RequestReroll:FireServer(e.uid)
    end
end)
inv.Buttons.Close.Activated:Connect(function()
    show("lobby")
end)

lobby.Side.Buttons.OpenCrate.Activated:Connect(function()
    show("crate")
    renderCrate()
end)
lobby.Side.Buttons.OpenInventory.Activated:Connect(function()
    inv.Status.Text = ""
    show("inventory")
    renderInventory()
end)
results.Lower.Buttons.NextRound.Activated:Connect(function()
    show("lobby")
end)
results.Lower.Buttons.OpenCrate.Activated:Connect(function()
    show("crate")
    renderCrate()
end)

Remotes.ShopResult.OnClientEvent:Connect(function(ok: boolean, message: string)
    local colour = ok and GREEN or Theme.DANGER
    if current == "crate" then
        crateMessage(message, colour)
        if not reelRunning then
            spinning = false
        end
        renderCrate()
    elseif current == "inventory" then
        inv.Status.Text = message
        inv.Status.TextColor3 = colour
    end
end)

ClientState.On("data", function(d)
    renderSide()
    if current == "crate" then
        renderCrate()
    elseif current == "inventory" then
        if d.inventory ~= renderedInventory or d.equipped ~= renderedEquipped then
            renderInventory()
        else
            inv.Summary.Text = ("%d owned · %d coins"):format(#(d.inventory or {}), d.coins or 0)
        end
    end
end)

-- Regional policy arrives from the server shortly after join
for _, attr in { "PaidRandomItemsRestricted", "PaidItemTradingAllowed" } do
    plr:GetAttributeChangedSignal(attr):Connect(function()
        renderPlayers()
        renderSide()
        if current == "crate" then
            renderCrate()
        elseif current == "inventory" then
            renderInventoryButtons()
        end
    end)
end

---------------------------------------------------------------- Flow + layout
local function onState()
    local st = ClientState.GetRoundState()
    if st == "INTERMISSION" then
        myVote, tally, lastReward = nil, {}, nil
        if current == nil or current == "results" then
            show("lobby")
        end
    elseif st == "LOADING" then
        show("loading")
    elseif st == "REVEAL" then
        show(nil)
    elseif st == "ACTIVE" then
        if ClientState.role then
            show(nil)
        elseif current == nil then
            show("lobby") -- spectators and late joiners wait in the lobby menus
        end
    end
    renderVotes()
end
ReplicatedStorage:GetAttributeChangedSignal("RoundState"):Connect(onState)

-- Every Root is a fixed canvas; shrink it to fit phones
local function fit()
    local camera = workspace.CurrentCamera
    if not camera then
        return
    end
    local vp = camera.ViewportSize
    for _, g in guis do
        local root = g.Root
        local size = root.Size
        -- Never clamp above what fits: a floor of 0.35 left a 1040 wide canvas
        -- hanging off the side of a small phone. Small and on screen beats
        -- large and cut off.
        root.Scale.Scale = math.min((vp.X - 24) / size.X.Offset, (vp.Y - 24) / size.Y.Offset, 1)
    end
end
local viewportConn
local function watchCamera()
    if viewportConn then
        viewportConn:Disconnect()
    end
    local camera = workspace.CurrentCamera
    if camera then
        viewportConn = camera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
    end
    fit()
end
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera)
watchCamera()

renderPlayers()
renderSide()
renderVotes()
onState()

return MenuController
