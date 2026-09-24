-- Gamepasses and developer products. Ids and prices live in Shared/Products.
-- Hard rule: nothing here touches lethality, speed or vision.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local Products = require(game.ReplicatedStorage.Shared.Products)
local Config = require(game.ReplicatedStorage.Shared.Config)
local Catalog = require(game.ReplicatedStorage.Shared.Catalog)
local Remotes = game.ReplicatedStorage.Remotes
local DataService = require(script.Parent.DataService)
local Analytics = require(script.Parent.Analytics)

local MonetizationService = {}
local MAX_RECEIPTS = 200
local charConns: { [Player]: RBXScriptConnection } = {}

-- Gold [VIP] over the head. Rides the core nametag, which VisionController
-- fog-gates every frame, so a VIP is never legible past the vision radius
-- mid-round - identity, never a tracking advantage.
local function markCharacter(plr: Player)
    local char = plr.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum then
        (hum :: Humanoid).DisplayName = "[VIP] " .. plr.DisplayName
    end
end

-- Everything a VIP owner is owed: the public tag attribute, the once-only
-- exclusive aura, and the head marker. Safe to call more than once.
function MonetizationService:ApplyVip(plr: Player, data)
    local isVip = data.passes.vip == true
    plr:SetAttribute("Vip", isVip) -- public: read by the chat tag and future UI
    if not isVip then
        return
    end
    if not data.onboarding.vipSkin then
        local item = Catalog[Config.VIP_SKIN]
        if item then
            local entry =
                { id = Config.VIP_SKIN, uid = HttpService:GenerateGUID(false), at = os.time() }
            table.insert(data.inventory, entry)
            data.onboarding.vipSkin = true
            Remotes.CrateResult:FireClient(
                plr,
                { id = entry.id, uid = entry.uid, rarity = item.rarity, gift = true }
            )
            Remotes.DataChanged:FireClient(plr, { inventory = data.inventory })
            Remotes.Notify:FireClient(plr, ("VIP gift · %s"):format(item.name))
        end
    end
    if not charConns[plr] then
        charConns[plr] = plr.CharacterAdded:Connect(function()
            task.defer(markCharacter, plr)
        end)
    end
    markCharacter(plr)
end

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
    MonetizationService:ApplyVip(plr, data)
end

DataService.Loaded.Event:Connect(function(plr: Player)
    MonetizationService:Refresh(plr)
end)

Players.PlayerRemoving:Connect(function(plr)
    local conn = charConns[plr]
    if conn then
        conn:Disconnect()
        charConns[plr] = nil
    end
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
            if key == "vip" then
                MonetizationService:ApplyVip(plr, data) -- mint the aura and tag on the spot
            end
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
