-- Lobby trade tables: when two players are seated across the same table, open a
-- trade between them; when a chair empties, close it. The existing TradeService
-- owns everything after that (offers, locks, confirms, the value/fairness UI).
-- Sitting together is the mutual consent an invite would otherwise require.
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TradeService = require(script.Parent.TradeService)
local LiveOps = require(ReplicatedStorage.Shared.LiveOps)
local Remotes = ReplicatedStorage.Remotes

local TradeTableService = {}
local seated: { [Model]: { Player } } = {} -- the pair a table last opened

local function tradingOpen(): boolean
    return ReplicatedStorage:GetAttribute("TradingOpen") == true
end

local function playerOf(seat: Seat): Player?
    local occupant = seat.Occupant
    local char = occupant and occupant.Parent
    return char and Players:GetPlayerFromCharacter(char) or nil
end

local function chairsOf(model: Model): { Seat }
    local out = {}
    for _, d in model:GetDescendants() do
        if d:IsA("Seat") then
            table.insert(out, d)
        end
    end
    return out
end

local function evaluate(model: Model)
    local chairs = chairsOf(model)
    if #chairs < 2 then
        return
    end
    local a, b = playerOf(chairs[1]), playerOf(chairs[2])
    if a and b and a ~= b then
        TradeService:OpenAtTable(a, b)
        seated[model] = { a, b }
    else
        -- a chair emptied: end whatever trade this table had going
        local prev = seated[model]
        if prev then
            for _, plr in prev do
                if plr.Parent == Players then
                    TradeService:CloseFor(plr)
                end
            end
            seated[model] = nil
        end
    end
end

-- Seat a player at a free chair of this table when they trigger the prompt.
-- Sitting is still the mutual consent: two players in the two chairs open the
-- trade (evaluate). Before the Day-28 unlock, say so instead of a dead press.
local function sitAt(model: Model, plr: Player)
    local char = plr.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hum then
        return
    end
    if not tradingOpen() then
        local day = ReplicatedStorage:GetAttribute("TradingOpensDay") or LiveOps.TRADING_UNLOCK_DAY
        Remotes.Notify:FireClient(plr, ("Trading unlocks on Day %d."):format(day))
        return
    end
    for _, seat in chairsOf(model) do
        if not seat.Occupant then
            seat:Sit(hum)
            return
        end
    end
    Remotes.Notify:FireClient(plr, "Both seats are taken.")
end

-- The table's floating sign reflects whether trading is open yet.
local function refreshSign(model: Model)
    local top = model.PrimaryPart or model:FindFirstChild("Top")
    local sign = top and top:FindFirstChild("Sign")
    local label = sign and sign:FindFirstChild("Label")
    if label and label:IsA("TextLabel") then
        if tradingOpen() then
            label.Text = "TRADE · SIT TO DEAL"
        else
            local day = ReplicatedStorage:GetAttribute("TradingOpensDay")
                or LiveOps.TRADING_UNLOCK_DAY
            label.Text = ("TRADE · OPENS DAY %d"):format(day)
        end
    end
end

local function watch(model: Model)
    for _, seat in chairsOf(model) do
        seat:GetPropertyChangedSignal("Occupant"):Connect(function()
            evaluate(model)
        end)
    end
    local top = model.PrimaryPart or model:FindFirstChild("Top")
    local prompt = top and top:FindFirstChild("TradePrompt")
    if prompt and prompt:IsA("ProximityPrompt") then
        prompt.Triggered:Connect(function(plr)
            sitAt(model, plr)
        end)
    end
    refreshSign(model)
end

for _, model in CollectionService:GetTagged("TradeTable") do
    watch(model)
end
CollectionService:GetInstanceAddedSignal("TradeTable"):Connect(watch)

-- Keep every sign current when the trading window opens or closes.
ReplicatedStorage:GetAttributeChangedSignal("TradingOpen"):Connect(function()
    for _, model in CollectionService:GetTagged("TradeTable") do
        refreshSign(model)
    end
end)

return TradeTableService
