-- Robux gamepasses and developer products (Design Bible · Robux).
-- Replace each `id = 0` with the real id from the Creator Dashboard. An id of
-- 0 is never offered or granted.
-- Hard rule: nothing purchasable touches lethality, speed, or vision.
return {
    PASSES = {
        vip = { id = 1976480741, name = "VIP", price = 399, coinMultiplier = 1.25 },
        -- Radio and Emote bundle perks are not built; both passes are off sale
        radio = { id = 1975550715, name = "Radio", price = 149 },
        emotes = { id = 1979660285, name = "Emote bundle", price = 99 },
    },
    PRODUCTS = {
        coins2500 = { id = 3712294448, name = "2,500 coins", price = 199, coins = 2500 },
        seasonalKey = { id = 3712294475, name = "Seasonal crate key", price = 79, seasonalKeys = 1 },
    },
}
