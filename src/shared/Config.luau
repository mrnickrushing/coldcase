-- COLD CASE · every tuning number lives here
return {
    -- Round
    INTERMISSION = 20,
    LOADING_TIME = 3,
    REVEAL_TIME = 4,
    RESOLUTION_TIME = 6,
    ROUND_LENGTH_SMALL = 90, -- fewer than 8 players
    ROUND_LENGTH = 120,
    ROUND_LENGTH_LARGE = 150, -- 12+ players
    MIN_PLAYERS = 4,
    SPAWN_MIN_SEP = 130,
    WEAPON_GRACE = 4, -- no kills for the first 4 seconds

    -- Role scaling
    SECOND_MURDERER_AT = 12,
    SECOND_SHERIFF_AT = 14,
    MEDIC_AT = 10,
    SNITCH_AT = 10,
    SNITCH_REVEAL_AT = 30, -- seconds remaining
    MURDERER_COOLOFF = 3, -- rounds of reduced odds after being murderer

    -- Combat
    KNIFE_RANGE = 12,
    PING_ALLOWANCE = 2, -- extra studs the server grants on top of KNIFE_RANGE
    KNIFE_COOLDOWN = 1.1,
    THROW_COOLDOWN = 8,
    THROW_SPEED = 90,
    THROW_MAX_FLIGHT = 1.2, -- seconds before a thrown knife drops
    GUN_COOLDOWN = 0.75,
    GUN_RANGE = 300,
    GUN_PICKUP_RANGE = 10,
    SHERIFF_MISFIRE_KILLS_SELF = true,

    -- Evidence
    BODY_CLUE_WINDOW = 20,
    EXAMINE_TIME = 1.5,
    EXAMINE_RANGE = 14,
    EXAMINE_REWARD = 15,
    DRAG_TIME = 2,
    WITNESS_LOS_TIME = 1.0,

    -- Events
    EVENT_AT_PCT = 0.45,
    LIGHTS_OUT_DUR = 13,
    LOCKDOWN_DUR = 20,
    FOG_DUR = 18,
    LAST_CALL_AT = 30,

    -- Economy
    STARTING_COINS = 100, -- below CRATE_COST so the second crate is locked in round two
    COIN_PICKUP = 5,
    COIN_PICKUP_RANGE = 7,
    COIN_NODES = 16,
    COINS_SURVIVE = 40,
    COINS_WIN = 90,
    COINS_LOSS = 30,
    CRATE_COST = 250,
    SEASONAL_COST = 600,
    CRAFT_DUPES = 5,
    CRAFT_FEE = 150,
    FRIEND_COIN_BONUS = 0.25, -- +25% when a friend is in the server
    STREAK_COINS_PER_DAY = 50,
    STREAK_COINS_MAX = 400,

    -- Progression
    XP_WIN = 120,
    XP_LOSS = 45,
    XP_SURVIVE = 60,
    XP_PER_CLUE = 10,
    XP_PER_RANK = 1200,
    RANK_GIFT_AT = 5,
    RANK_GIFT_RARITY = "Rare",

    -- Anti-exploit
    REMOTE_CALLS_PER_SEC = 20, -- hard ceiling per player, across every RemoteEvent
    REMOTE_STRIKES_TO_KICK = 5, -- seconds over the ceiling...
    REMOTE_STRIKE_WINDOW = 10, -- ...within this many seconds

    -- Analytics
    HEATMAP_CELL = 80, -- studs per death-position grid cell

    MAPS = { "BlackwoodManor", "RustedPier", "CityArchive" },
}
