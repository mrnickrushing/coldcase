-- Gamepasses and developer products. Ids and prices live in Shared/Products.
-- Hard rule: nothing here touches lethality, speed or vision.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local Products = require(game.ReplicatedStorage.Shared.Products)
local Remotes = game.ReplicatedStorage.Remotes
local DataService = require(script.Parent.DataService)
local Analytics = require(script.Parent.Analytics)

local MonetizationService = {}
local MAX_RECEIPTS = 200

function MonetizationService:HasPass(plr: Player, key: string): boolean
    local data = DataService:Get(plr)
    return data ~= nil and data.passes[key] == true
end

function MonetizationService:Refresh(plr: Player)
    local data = DataService:Get(plr)
    if not data then
        return
    end
    for key, pass in Products.PASSES do
        if pass.id ~= 0 then
            local ok, owns = pcall(
                MarketplaceService.UserOwnsGamePassAsync,
                MarketplaceService,
                plr.UserId,
                pass.id
            )
            if ok then
                data.passes[key] = owns or nil
            end
        end
    end
    Remotes.DataChanged:FireClient(plr, { passes = data.passes })
end

DataService.Loaded.Event:Connect(function(plr: Player)
    MonetizationService:Refresh(plr)
end)

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(plr, passId, purchased)
    if not purchased then
        return
    end
    local data = DataService:Get(plr)
    for key, pass in Products.PASSES do
        if data and pass.id ~= 0 and pass.id == passId then
            data.passes[key] = true
            Remotes.DataChanged:FireClient(plr, { passes = data.passes })
        end
    end
end)

local function productById(productId: number)
    for _, product in Products.PRODUCTS do
        if product.id ~= 0 and product.id == productId then
            return product
        end
    end
    return nil
end

-- Keep the receipt log bounded; Roblox only redelivers unacknowledged receipts
local function prune(purchases)
    local ids = {}
    for id, at in purchases do
        table.insert(ids, { id = id, at = at })
    end
    if #ids <= MAX_RECEIPTS then
        return
    end
    table.sort(ids, function(a, b)
        return a.at < b.at
    end)
    for i = 1, #ids - MAX_RECEIPTS do
        purchases[ids[i].id] = nil
    end
end

MarketplaceService.ProcessReceipt = function(receipt)
    local plr = Players:GetPlayerByUserId(receipt.PlayerId)
    local data = plr and DataService:Get(plr)
    local product = productById(receipt.ProductId)
    if not (plr and data and product) then
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end

    -- A receipt can arrive more than once. Grant each PurchaseId exactly once.
    if data.purchases[receipt.PurchaseId] then
        return Enum.ProductPurchaseDecision.PurchaseGranted
    end

    if product.coins then
        data.coins += product.coins -- raw: purchases never pick up gameplay multipliers
        Analytics.CoinsEarned(plr, "robux", product.coins, data.coins, 0)
    end
    if product.seasonalKeys then
        data.seasonalKeys += product.seasonalKeys
    end
    data.purchases[receipt.PurchaseId] = os.time()
    prune(data.purchases)

    Remotes.DataChanged:FireClient(plr, { coins = data.coins, seasonalKeys = data.seasonalKeys })
    return Enum.ProductPurchaseDecision.PurchaseGranted
end

return MonetizationService
