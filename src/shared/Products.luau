-- Robux gamepasses and developer products (Design Bible · Robux).
-- Replace each `id = 0` with the real id from the Creator Dashboard. An id of
-- 0 is never offered or granted.
-- Hard rule: nothing purchasable touches lethality, speed, or vision.
return {
    PASSES = {
        vip = { id = 0, name = "VIP", price = 399, coinMultiplier = 1.25 },
        radio = { id = 0, name = "Radio", price = 149 },
        emotes = { id = 0, name = "Emote bundle", price = 99 },
    },
    PRODUCTS = {
        coins2500 = { id = 0, name = "2,500 coins", price = 199, coins = 2500 },
        seasonalKey = { id = 0, name = "Seasonal crate key", price = 79, seasonalKeys = 1 },
    },
}
