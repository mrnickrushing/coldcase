-- Roblox policy APIs for paid random items and paid item trading.
-- Resolved once per player on join and published as Player attributes, so the
-- client can explain why a feature is unavailable. Fails closed: while the
-- lookup is pending or has failed, the player is treated as restricted.
local Players = game:GetService("Players")
local PolicyService = game:GetService("PolicyService")

local PlayerPolicy = {}
local cache: { [Player]: { randomItemsRestricted: boolean, tradingAllowed: boolean } } = {}
local RETRY_DELAY = 10
local MAX_TRIES = 3

local function apply(plr: Player, randomItemsRestricted: boolean, tradingAllowed: boolean)
    cache[plr] = { randomItemsRestricted = randomItemsRestricted, tradingAllowed = tradingAllowed }
    plr:SetAttribute("PaidRandomItemsRestricted", randomItemsRestricted)
    plr:SetAttribute("PaidItemTradingAllowed", tradingAllowed)
end

local function resolve(plr: Player)
    apply(plr, true, false)
    for _ = 1, MAX_TRIES do
        local ok, info = pcall(PolicyService.GetPolicyInfoForPlayerAsync, PolicyService, plr)
        if plr.Parent ~= Players then
            return
        end
        if ok and type(info) == "table" then
            apply(
                plr,
                info.ArePaidRandomItemsRestricted == true,
                info.IsPaidItemTradingAllowed == true
            )
            return
        end
        task.wait(RETRY_DELAY)
    end
end

-- Crates bought with coins or keys, crafting and effect re-rolls all hand out
-- a random result for something that can be bought with Robux
function PlayerPolicy:CanUsePaidRandomItems(plr: Player): boolean
    local c = cache[plr]
    return c ~= nil and not c.randomItemsRestricted
end

function PlayerPolicy:CanTradePaidItems(plr: Player): boolean
    local c = cache[plr]
    return c ~= nil and c.tradingAllowed
end

Players.PlayerAdded:Connect(function(plr)
    task.spawn(resolve, plr)
end)
for _, plr in Players:GetPlayers() do
    task.spawn(resolve, plr)
end
Players.PlayerRemoving:Connect(function(plr)
    cache[plr] = nil
end)

return PlayerPolicy
