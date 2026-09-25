--!strict
-- The 24 launch items plus seasonal drops. Rarity, kind and value are FIXED
-- per item — never roll a name and a rarity independently.
-- `season` marks an item that only drops from that season's crate and is
-- retired forever when the season closes (see Shared/LiveOps).
return {
    -- Common
    -- `starter` items are given, never dropped: pulling the thing you already
    -- own on round one is the worst possible first crate.
    ash = { name = "Ash", kind = "Knife", rarity = "Common", value = 40, starter = true },
    tallow = { name = "Tallow", kind = "Knife", rarity = "Common", value = 40 },
    ledger = { name = "Ledger", kind = "Pistol", rarity = "Common", value = 40, starter = true },
    scrap = { name = "Scrap", kind = "Pistol", rarity = "Common", value = 40 },
    matchstick = { name = "Matchstick", kind = "Effect", rarity = "Common", value = 60 },
    gutter = { name = "Gutter", kind = "Knife", rarity = "Common", value = 40 },
    -- Uncommon
    ember = { name = "Ember", kind = "Knife", rarity = "Uncommon", value = 180 },
    hollow = { name = "Hollow", kind = "Knife", rarity = "Uncommon", value = 180 },
    static = { name = "Static", kind = "Effect", rarity = "Uncommon", value = 220 },
    brassnine = { name = "Brass Nine", kind = "Pistol", rarity = "Uncommon", value = 180 },
    moth = { name = "Moth", kind = "Pet", rarity = "Uncommon", value = 260 },
    palefox = { name = "Pale Fox", kind = "Knife", rarity = "Uncommon", value = 200 },
    -- Rare
    nocturne = { name = "Nocturne", kind = "Knife", rarity = "Rare", value = 900 },
    ivory = { name = "Ivory", kind = "Pistol", rarity = "Rare", value = 850 },
    longnight = { name = "Longnight", kind = "Knife", rarity = "Rare", value = 1100 },
    frostbite = { name = "Frostbite", kind = "Effect", rarity = "Rare", value = 1000 },
    copperhead = { name = "Copperhead", kind = "Pistol", rarity = "Rare", value = 850 },
    widowspeak = { name = "Widow's Peak", kind = "Pet", rarity = "Rare", value = 1300 },
    -- Legendary
    verdict = { name = "Verdict", kind = "Knife", rarity = "Legendary", value = 4200 },
    cinder = { name = "Cinder", kind = "Knife", rarity = "Legendary", value = 4500 },
    nightjar = { name = "Nightjar", kind = "Pistol", rarity = "Legendary", value = 5000 },
    bellwether = { name = "Bellwether", kind = "Effect", rarity = "Legendary", value = 4800 },
    -- Godly
    coldsnap = { name = "Coldsnap", kind = "Knife", rarity = "Godly", value = 22000 },
    thealibi = { name = "The Alibi", kind = "Pistol", rarity = "Godly", value = 28000 },

    -- Ancient · chroma. The rarest pull (~0.2%): a top mesh whose blade cycles
    -- through every hue. `chroma` is read by ItemCard and CosmeticService.
    eclipse = { name = "Eclipse", kind = "Knife", rarity = "Ancient", value = 60000, chroma = true },
    prism = { name = "Prism", kind = "Pistol", rarity = "Ancient", value = 65000, chroma = true },

    -- VIP exclusive. `vip` items never drop from a crate or craft; the VIP pass
    -- mints exactly one, once, when the pass is owned (see MonetizationService).
    regalia = { name = "Regalia", kind = "Effect", rarity = "Legendary", value = 5000, vip = true },

    -- Season One · The Long Night. Values are placeholders until the
    -- market sets them; the handbook does not price seasonals.
    vigil = { name = "Vigil", kind = "Knife", rarity = "Rare", value = 1200, season = "S1" },
    hoarfrost = {
        name = "Hoarfrost",
        kind = "Pistol",
        rarity = "Rare",
        value = 1200,
        season = "S1",
    },
    thelongnightfx = {
        name = "The Long Night",
        kind = "Effect",
        rarity = "Legendary",
        value = 5000,
        season = "S1",
    },
    nightwatch = {
        name = "Nightwatch",
        kind = "Pet",
        rarity = "Legendary",
        value = 5000,
        season = "S1",
    },
}
