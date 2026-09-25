-- Lobby trade tables: when two players are seated across the same table, open a
-- trade between them; when a chair empties, close it. The existing TradeService
-- owns everything after that (offers, locks, confirms, the value/fairness UI).
-- Sitting together is the mutual consent an invite would otherwise require.
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local TradeService = require(script.Parent.TradeService)

local TradeTableService = {}
local seated: { [Model]: { Player } } = {} -- the pair a table last opened

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

local function watch(model: Model)
    for _, seat in chairsOf(model) do
        seat:GetPropertyChangedSignal("Occupant"):Connect(function()
            evaluate(model)
        end)
    end
end

for _, model in CollectionService:GetTagged("TradeTable") do
    watch(model)
end
CollectionService:GetInstanceAddedSignal("TradeTable"):Connect(watch)

return TradeTableService
