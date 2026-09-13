--!strict
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

-- Which equipped slot an item kind occupies. The server decides whether an
-- equip is legal and the client decides whether to draw "EQUIPPED"; a fifth
-- kind known to only one of them is an item that equips but never looks it.
Shop.SLOT_FOR_KIND = { Knife = "knife", Pistol = "gun", Effect = "effect", Pet = "pet" }

-- Total catalogue value of one side of a trade. The client draws the fairness
-- meter from this and the server logs the completed trade with it, so the two
-- must not drift or players see a bar that disagrees with the record.
function Shop.ValueOf(entries: { { id: string } }): number
    local total = 0
    for _, entry in entries do
        local item = Catalog[entry.id]
        total += item and item.value or 0
    end
    return total
end

return Shop
