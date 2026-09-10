-- Rank titles and rank perks. Pure module: no Roblox services, so it runs
-- under Lune tests too.
local Progression = {}

Progression.TITLES = {
    { 1, "Bystander" },
    { 5, "Witness" },
    { 10, "Investigator" },
    { 25, "Detective" },
    { 50, "Inspector" },
    { 75, "Chief" },
    { 100, "Cold Case" },
}

function Progression.TitleFor(rank: number): string
    local best = Progression.TITLES[1][2]
    for _, t in Progression.TITLES do
        if rank >= t[1] then
            best = t[2]
        end
    end
    return best
end

-- The rank-25 crate discount
function Progression.CratePrice(
    baseCost: number,
    rank: number,
    discountRank: number,
    discountAmount: number
): number
    if rank >= discountRank then
        return math.max(0, baseCost - discountAmount)
    end
    return baseCost
end

return Progression
