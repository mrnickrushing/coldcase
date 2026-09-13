-- COLD CASE · every tuning number lives here
return {
    -- Round
    INTERMISSION = 20,
    LOADING_TIME = 3,
    REVEAL_TIME = 4,
    RESOLUTION_TIME = 6,
    KILLCAM_TIME = 2.5, -- of RESOLUTION_TIME, before the results screen
    ROUND_LENGTH_SMALL = 110, -- fewer than 8 players; the buildings are big
    ROUND_LENGTH = 120,
    ROUND_LENGTH_LARGE = 150, -- 12+ players
    MIN_PLAYERS = 4,
    SPAWN_MIN_SEP = 60,
    WEAPON_GRACE = 4, -- no kills for the first 4 seconds

    -- Role scaling
    SECOND_MURDERER_AT = 12,
    SECOND_SHERIFF_AT = 14,
    MEDIC_AT = 6, -- NPC rounds seat 6: below this the role never existed
    SNITCH_AT = 6,
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
    WEAPON_DRAW_TIME = 1.2, -- weapons are carried hidden and drawn only while used

    -- Evidence
    BODY_CLUE_WINDOW = 20,
    EXAMINE_TIME = 1.5,
    EXAMINE_RANGE = 14,
    EXAMINE_REWARD = 15,
    DRAG_TIME = 2,
    WITNESS_LOS_TIME = 1.0, -- seconds of unbroken line of sight for a witness clue
    WITNESS_WINDOW = 10, -- ...that must end within this many seconds of the death
    SIGHTLINE_RANGE = 90,
    SIGHTLINE_SAMPLE = 0.25,

    -- Abilities
    REVIVE_CHANNEL = 3,
    REVIVE_MOVE_TOLERANCE = 3, -- studs; moving further breaks the channel
    REVIVE_COINS = 60,
    REVIVE_XP = 40,
    DRAG_WALKSPEED = 8,
    DRAG_SOUND_INTERVAL = 0.8,

    -- Vision (client-side radius, in studs)
    VISION_NORMAL = 130, -- past the 60 stud median sightline, short of the 240 longest
    VISION_DARK = 88,
    VISION_SURGE = 130,
    FOG_NAMETAG_RANGE = 40,

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
    DIRECT_BUY_MARKUP = 1.6, -- direct buy is the impatience tax
    REROLL_COST = 300,
    DISCOUNT_RANK = 25,
    DISCOUNT_AMOUNT = 25, -- coins off every crate
    LAST_CALL_MULT = 2,
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
    -- Tighter ceilings for single remotes, on top of the global one (calls/sec)
    REMOTE_LIMITS = {
        RequestStab = 4,
        RequestShoot = 4,
        RequestThrow = 2,
        RequestExamine = 6,
        RequestCoin = 30,
        RequestVote = 4,
        RequestCrate = 3,
        RequestBuy = 3,
        RequestTrade = 10,
        RequestRadio = 2,
        RequestEmote = 3,
        RequestReport = 2,
        RequestSpectate = 4,
        RequestLobbyMode = 4,
    },

    -- Social: Radio and Emote passes, reports
    RADIO_COOLDOWN = 3,
    RADIO_MAX_CHARS = 100,
    EMOTE_COOLDOWN = 2,
    EMOTES = { "wave", "point", "shrug", "laugh", "panic" },
    REPORT_REASONS = { "exploiting", "harassment", "other" },

    -- NPCs fill a quiet server so one person can play (BotService)
    BOTS_ENABLED = true,
    BOT_FILL_TO = 6, -- players who chose Play now + NPCs, while humans < MIN_PLAYERS
    BOT_ROUND_REWARD = 1, -- coins and XP scale in a round with NPCs (1 = full pay)
    BOT_FIRST_HUNT = { 9, 16 }, -- seconds before an NPC murderer first strikes
    BOT_HUNT_PAUSE = { 6, 11 }, -- seconds between an NPC murderer's kills
    BOT_REACTION = { 0.9, 1.6 }, -- seconds before an NPC sheriff fires on a killer
    BOT_SIGHT = 70, -- studs an NPC can witness a kill from
    BOT_STROLL_SPEED = 11, -- NPCs walk; they only run to chase or flee
    BOT_CHASE_GIVE_UP = 12, -- seconds an NPC murderer chases one target

    -- Analytics
    HEATMAP_CELL = 80, -- studs per death-position grid cell

    MAPS = { "BlackwoodManor", "RustedPier", "CityArchive" }, -- layouts live in Shared/MapPlan
}
