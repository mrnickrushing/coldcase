-- COLD CASE · the twenty-two sound cues from the production handbook.
-- In a deduction game sound is information, so every cue has a deliberate
-- range. `range = nil` is 2D (local to one client). A number is the audible
-- radius in studs: the server only tells clients inside that radius, so an
-- exploiter cannot read a map-wide list of where every knife swing happened.
--
-- Sounds come from the Roblox Creator Store, almost all from the licensed Pro
-- Sound Effects and APM Music libraries (gun_fire is DocInk's own upload).
-- An empty `soundId` is skipped silently. Swap ids here; nothing else changes.
export type Cue = {
    group: string,
    range: number?,
    volume: number,
    soundId: string,
    desc: string,
}

local cues: { [string]: Cue } = {
    -- ROUND
    round_reveal = {
        group = "ROUND",
        volume = 0.8,
        soundId = "rbxassetid://9038130941",
        desc = "Single struck piano note, long decay, under the role card. Pitch per role.",
    },
    round_start = {
        group = "ROUND",
        volume = 0.7,
        soundId = "rbxassetid://9043340902",
        desc = "A distant door closing. Dry, no reverb tail.",
    },
    timer_30 = {
        group = "ROUND",
        volume = 0.5,
        soundId = "rbxassetid://9120098166",
        desc = "Low clock tick once per second, fading in over the last 30s.",
    },
    round_win = {
        group = "ROUND",
        volume = 0.8,
        soundId = "rbxassetid://94590027038118",
        desc = "Warm brass swell, 1.5s. Only major-key sound.",
    },
    round_lose = {
        group = "ROUND",
        volume = 0.8,
        soundId = "rbxassetid://1837830084",
        desc = "Sub-bass drop with a tape stop. Short.",
    },

    -- COMBAT
    knife_swing = {
        group = "COMBAT",
        range = 40,
        volume = 0.6,
        soundId = "rbxassetid://9120972444",
        desc = "Air displacement, no metal ring. Hearable but not obvious.",
    },
    knife_hit = {
        group = "COMBAT",
        range = 70,
        volume = 1.0,
        soundId = "rbxassetid://9113480915",
        desc = "Heavy dull impact, wet transient. Loudest diegetic sound.",
    },
    knife_throw = {
        group = "COMBAT",
        range = 55,
        volume = 0.8,
        soundId = "rbxassetid://9114156616",
        desc = "Rising whistle over 0.4s. Gives the target a chance to react.",
    },
    gun_fire = {
        group = "COMBAT",
        range = 220,
        volume = 1.0,
        soundId = "rbxassetid://17761500292",
        desc = "Sharp crack, long slap-back. Everyone knows roughly where.",
    },
    gun_pickup = {
        group = "COMBAT",
        range = 25,
        volume = 0.7,
        soundId = "rbxassetid://9113104176",
        desc = "Metallic scrape and hammer cock. Signals a hero nearby.",
    },
    misfire_death = {
        group = "COMBAT",
        volume = 0.9,
        soundId = "rbxassetid://9125626779",
        desc = "Reverse cymbal into silence. The sheriff knows what they did.",
    },

    -- EVIDENCE
    body_drop = {
        group = "EVIDENCE",
        range = 60,
        volume = 0.8,
        soundId = "rbxassetid://9113480917",
        desc = "Soft collapse, then a beat of nothing.",
    },
    examine_start = {
        group = "EVIDENCE",
        range = 15,
        volume = 0.5,
        soundId = "rbxassetid://9117233449",
        desc = "Paper rustle under the 1.5s channel. Investigating is public.",
    },
    clue_found = {
        group = "EVIDENCE",
        volume = 0.7,
        soundId = "rbxassetid://1841210107",
        desc = "Three ascending marimba notes, one per clue line.",
    },
    trail_cold = {
        group = "EVIDENCE",
        volume = 0.6,
        soundId = "rbxassetid://9120887046",
        desc = "A single flat low tone.",
    },
    body_drag = {
        group = "EVIDENCE",
        range = 35,
        volume = 0.9,
        soundId = "rbxassetid://9125883698",
        desc = "Continuous scrape. Deliberately loud.",
    },

    -- EVENTS & META
    lights_out = {
        group = "EVENTS",
        volume = 0.9,
        soundId = "rbxassetid://9113112330",
        desc = "Power-down whine over 1.2s, then room tone drops to almost nothing.",
    },
    power_surge = {
        group = "EVENTS",
        volume = 0.8,
        soundId = "rbxassetid://9114237487",
        desc = "Electrical arcing, irregular. Never loops cleanly.",
    },
    -- The 2D layer everyone hears is played by EventService alongside the
    -- per-door positional cues. It is not a flag here: AudioService:Emit
    -- range-filters on purpose, and broadcasting from inside it would send
    -- one layer per door and undo that.
    lockdown = {
        group = "EVENTS",
        range = 80,
        volume = 0.9,
        soundId = "rbxassetid://9114143852",
        desc = "Four bolts throwing in sequence, each at its real door position.",
    },
    crate_spin = {
        group = "META",
        volume = 0.6,
        soundId = "rbxassetid://9116784575",
        desc = "Ratcheting tick that slows with the reel; pitch rises on the last three.",
    },
    crate_godly = {
        group = "META",
        volume = 0.9,
        soundId = "rbxassetid://1841760054",
        desc = "Held choral chord with a bell. Legendary and Godly only.",
    },
    trade_complete = {
        group = "META",
        volume = 0.6,
        soundId = "rbxassetid://9114144264",
        desc = "Two short clicks, like a case latching.",
    },
}

-- round_reveal pitch per role, so players hear their role before reading it
local ROLE_PITCH = {
    innocent = 1.0,
    sheriff = 1.26,
    murderer = 0.75,
    hero = 1.5,
    medic = 1.12,
    snitch = 0.89,
}

return {
    cues = cues,
    ROLE_PITCH = ROLE_PITCH,
}
