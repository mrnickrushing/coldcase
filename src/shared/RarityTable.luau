--!strict
-- Pull weights for The Locker. Publish these in-game; Roblox requires
-- disclosure on paid random items and visible odds increase pull rates.
return {
    { name = "Common", weight = 55.8, colour = Color3.fromHex("6d7580"), announce = false },
    { name = "Uncommon", weight = 24.0, colour = Color3.fromHex("4fb0a0"), announce = false },
    { name = "Rare", weight = 13.0, colour = Color3.fromHex("4f86e8"), announce = false },
    { name = "Legendary", weight = 5.5, colour = Color3.fromHex("b45fe8"), announce = true },
    { name = "Godly", weight = 1.5, colour = Color3.fromHex("f2a63b"), announce = true },
    -- The prestige tier above Godly: only the chroma items live here, at a ~0.2%
    -- pull. Iridescent white so it reads apart from Godly's gold.
    { name = "Ancient", weight = 0.2, colour = Color3.fromHex("cdeee9"), announce = true },
}
