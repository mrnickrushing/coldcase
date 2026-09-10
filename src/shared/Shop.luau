-- Direct buys, effect re-rolls and crate pricing, shared so the client shows
-- exactly the prices the server charges.
local Catalog = require(script.Parent.Catalog)
local Config = require(script.Parent.Config)
local Progression = require(script.Parent.Progression)

local Shop = {}

-- Direct-buy shelf. Priced above crate expected value on purpose: buying
-- outright is the impatience tax, not the cheap route.
Shop.SHELF = { "ember", "nocturne", "ivory", "verdict" }

-- Knife effects a re-roll can land on. Pure visual churn.
Shop.EFFECTS = { "none", "ember", "frost", "static", "ash", "gold" }

function Shop.PriceOf(id: string): number?
    local def = Catalog[id]
    if not def then
        return nil
    end
    return math.floor(def.value * Config.DIRECT_BUY_MARKUP)
end

function Shop.CratePrice(baseCost: number, rank: number): number
    return Progression.CratePrice(baseCost, rank, Config.DISCOUNT_RANK, Config.DISCOUNT_AMOUNT)
end

return Shop
