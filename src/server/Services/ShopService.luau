-- Direct coin purchases and knife-effect re-rolls (Design Bible · Sinks).
-- Prices come from Shared/Shop so the client shows exactly what is charged.
local Shared = game.ReplicatedStorage.Shared
local Catalog = require(Shared.Catalog)
local Config = require(Shared.Config)
local Shop = require(Shared.Shop)
local Remotes = game.ReplicatedStorage.Remotes
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local Analytics = require(script.Parent.Analytics)

local ShopService = {}

local function reply(plr: Player, ok: boolean, message: string)
    Remotes.ShopResult:FireClient(plr, ok, message)
end

function ShopService:Buy(plr: Player, id: string)
    if not table.find(Shop.SHELF, id) then
        return
    end
    local data = DataService:Get(plr)
    local price = Shop.PriceOf(id)
    if not (data and price) then
        return
    end
    if data.coins < price then
        reply(plr, false, ("You are %d coins short."):format(price - data.coins))
        return
    end

    local entry = EconomyService:GiveItem(data, id)
    if not entry then
        return
    end
    data.coins -= price
    Analytics.CoinsSpent(plr, "shop", price, data.coins)
    reply(plr, true, ("%s added to your collection."):format(Catalog[id].name))
    Remotes.DataChanged:FireClient(plr, { coins = data.coins, inventory = data.inventory })
end

-- Re-roll the cosmetic effect on an owned knife. Always lands on a
-- different effect, so the coins are never spent on nothing.
function ShopService:RerollEffect(plr: Player, uid: string)
    local data = DataService:Get(plr)
    if not data then
        return
    end
    local target
    for _, item in data.inventory do
        if item.uid == uid then
            target = item
            break
        end
    end
    local def = target and Catalog[target.id]
    if not def or def.kind ~= "Knife" then
        return
    end
    if data.coins < Config.REROLL_COST then
        reply(plr, false, ("You are %d coins short."):format(Config.REROLL_COST - data.coins))
        return
    end

    local options = {}
    for _, effect in Shop.EFFECTS do
        if effect ~= (target.effect or "none") then
            table.insert(options, effect)
        end
    end
    target.effect = options[math.random(#options)]
    data.coins -= Config.REROLL_COST
    Analytics.CoinsSpent(plr, "reroll", Config.REROLL_COST, data.coins)
    reply(plr, true, ("%s effect: %s"):format(def.name, target.effect))
    Remotes.DataChanged:FireClient(plr, { coins = data.coins, inventory = data.inventory })
end

return ShopService
