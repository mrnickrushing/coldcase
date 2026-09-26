--!strict
-- COLD CASE · every tuning number lives here
return {
    -- Round
    INTERMISSION = 15, -- the lobby: vote, then NPCs fill the round and it starts on its own
    LOADING_TIME = 3,
    REVEAL_TIME = 4,
    RESOLUTION_TIME = 6,
    KILLCAM_TIME = 2.5, -- of RESOLUTION_TIME, before the results screen
    -- Four to five minutes. At 110-150s a family round was over before anyone
    -- had crossed the building twice, and a player killed early sat out longer
    -- than they had played; a later pass added a minute to every tier for more
    -- time to investigate and hunt.
    ROUND_LENGTH_SMALL = 240, -- fewer than 8 players; the buildings are big
    ROUND_LENGTH = 260,
    ROUND_LENGTH_LARGE = 300, -- 12+ players
    ROUND_SMALL_UNDER = 8, -- below this headcount a round uses the small length
    ROUND_LARGE_AT = 12, -- at or above it, the large one
    MIN_PLAYERS = 4,
    MODE_ROTATE_EVERY = 4, -- every Nth round runs a special mode (see Shared/Modes)
    -- The server cap. It mirrors the place's server size, which is set on the
    -- Creator Dashboard (it is not a place-file property: Rojo drops a
    -- Players.MaxPlayers entry without a word). Every headcount threshold
    -- below is checked against it.
    MAX_PLAYERS = 12,
    SPAWN_MIN_SEP = 60,
    WEAPON_GRACE = 4, -- no kills for the first 4 seconds

    -- Role scaling
    SECOND_MURDERER_AT = 12,
    -- Was 14, which no server could ever reach: the cap is 12, so a second
    -- sheriff never once appeared. Matched to the second murderer so a full
    -- lobby scales both sides together instead of only the killers.
    SECOND_SHERIFF_AT = 12,
    -- A medic can revive a person or an NPC, so a solo round of NPCs still
    -- deals the role at this headcount.
    MEDIC_AT = 6,
    SNITCH_AT = 6,
    SNITCH_REVEAL_AT = 30, -- seconds remaining
    -- The snitch's deduction: examining bodies builds a suspect board, and once
    -- they have read this many bodies (or the reveal fires) they may EXPOSE the
    -- real killer to everyone. One use; naming does not end the round.
    SNITCH_EXPOSE_CLUES = 3,
    SNITCH_EXPOSE_HIGHLIGHT = 4, -- seconds the named killer glows red to all
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
    -- Who may take a fallen sheriff's pistol and become the hero. Every
    -- unarmed civilian role, not innocents alone: a medic or a snitch standing
    -- over the gun could see it and not pick it up, which reads as the game
    -- being broken. A murderer never takes it, and a sheriff or hero is armed
    -- already. The client greys the prompt by this table and the server
    -- re-checks it in RoleService:MakeHero.
    PISTOL_ROLES = { innocent = true, medic = true, snitch = true },
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
    WALKSPEED = 16, -- base speed; what DRAG_WALKSPEED is restored back to
    DRAG_WALKSPEED = 8,
    DRAG_SOUND_INTERVAL = 0.8,

    -- Vision (client-side radius, in studs)
    VISION_NORMAL = 130, -- past the 60 stud median sightline, short of the 240 longest
    VISION_DARK = 88,
    VISION_SURGE = 130,
    VISION_HARDCORE = 70, -- reduced sight the whole round in Hardcore mode
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
    COINS_SURVIVE = 40,
    COINS_WIN = 90,
    COINS_LOSS = 30,
    CRATE_COST = 250,
    SEASONAL_COST = 600,
    CRAFT_DUPES = 5,
    CRAFT_FEE = 150,
    DIRECT_BUY_MARKUP = 1.6, -- direct buy is the impatience tax
    REROLL_COST = 300,
    MAX_TRADE_OFFER = 8, -- items one side may put on the table; both ends read this
    DISCOUNT_RANK = 25,
    DISCOUNT_AMOUNT = 25, -- coins off every crate
    LAST_CALL_MULT = 2,
    FRIEND_COIN_BONUS = 0.25, -- +25% when a friend is in the server
    STREAK_COINS_PER_DAY = 50,
    STREAK_COINS_MAX = 400,
    VIP_DAILY_BONUS = 150, -- coins a VIP owner is handed once per day at login
    VIP_SKIN = "regalia", -- the VIP-exclusive aura, minted once on ownership

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
    -- Tighter ceilings for single remotes, on top of the global one (calls/sec).
    -- Every client->server remote carries one, as defence in depth: each already
    -- has a stronger server-side gate (a role, a cooldown, a coin cost, a
    -- channel), but a dedicated cap is a backstop if a gate is ever weakened, and
    -- keeps one spammed remote from eating the whole global 20/sec budget. Values
    -- sit well above any legitimate rate, so real play never trips them.
    REMOTE_LIMITS = {
        RequestStab = 4,
        RequestShoot = 4,
        RequestThrow = 2,
        RequestExamine = 6,
        RequestPickup = 4,
        RequestCoin = 30,
        RequestVote = 4,
        RequestCrate = 3,
        RequestBuy = 3,
        RequestReroll = 3,
        RequestCraft = 3,
        RequestEquip = 8,
        RequestTrade = 10,
        RequestRadio = 2,
        RequestEmote = 3,
        RequestReport = 2,
        RequestRevive = 4,
        RequestDrag = 6,
        RequestSpectate = 4,
        RequestLobbyMode = 4,
        RequestExpose = 2, -- one use a round; a low cap is only anti-spam
        RequestAccuse = 4, -- Whodunnit: change your vote, not spam it
        RequestModeVote = 4, -- lobby: change your next-mode pick, not spam it
        HintSeen = 5,
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
    -- Paced to the longer round: at {9, 16} and {6, 11} an NPC murderer had
    -- cleared most of a six-seat round inside 90 seconds, and a lone human
    -- standing still to read a prompt was its first mark within 15.
    BOT_FIRST_HUNT = { 20, 35 }, -- seconds before an NPC murderer first strikes
    BOT_HUNT_PAUSE = { 14, 24 }, -- seconds between an NPC murderer's kills
    BOT_REACTION = { 0.9, 1.6 }, -- seconds before an NPC sheriff fires on a killer
    BOT_SIGHT = 70, -- studs an NPC can witness a kill from
    BOT_STROLL_SPEED = 11, -- NPCs walk; they only run to chase or flee
    BOT_CHASE_GIVE_UP = 12, -- seconds an NPC murderer chases one target

    -- Analytics
    HEATMAP_CELL = 80, -- studs per death-position grid cell

    MAPS = { "BlackwoodManor", "RustedPier", "CityArchive" }, -- layouts live in Shared/MapPlan
}
