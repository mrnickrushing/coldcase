-- COLD CASE · the twenty-two sound cues from the production handbook.
-- In a deduction game sound is information, so every cue has a deliberate
-- range. `range = nil` is 2D (local to one client). A number is the audible
-- radius in studs: the server only tells clients inside that radius, so an
-- exploiter cannot read a map-wide list of where every knife swing happened.
--
-- `soundId` is empty until audio is uploaded; empty cues are skipped silently.
export type Cue = {
    group: string,
    range: number?,
    twoD: boolean?, -- also play a 2D layer for everyone (lockdown)
    volume: number,
    soundId: string,
    desc: string,
}

local cues: { [string]: Cue } = {
    -- ROUND
    round_reveal = {
        group = "ROUND",
        volume = 0.8,
        soundId = "",
        desc = "Single struck piano note, long decay, under the role card. Pitch per role.",
    },
    round_start = {
        group = "ROUND",
        volume = 0.7,
        soundId = "",
        desc = "A distant door closing. Dry, no reverb tail.",
    },
    timer_30 = {
        group = "ROUND",
        volume = 0.5,
        soundId = "",
        desc = "Low clock tick once per second, fading in over the last 30s.",
    },
    round_win = {
        group = "ROUND",
        volume = 0.8,
        soundId = "",
        desc = "Warm brass swell, 1.5s. Only major-key sound.",
    },
    round_lose = {
        group = "ROUND",
        volume = 0.8,
        soundId = "",
        desc = "Sub-bass drop with a tape stop. Short.",
    },

    -- COMBAT
    knife_swing = {
        group = "COMBAT",
        range = 40,
        volume = 0.6,
        soundId = "",
        desc = "Air displacement, no metal ring. Hearable but not obvious.",
    },
    knife_hit = {
        group = "COMBAT",
        range = 70,
        volume = 1.0,
        soundId = "",
        desc = "Heavy dull impact, wet transient. Loudest diegetic sound.",
    },
    knife_throw = {
        group = "COMBAT",
        range = 55,
        volume = 0.8,
        soundId = "",
        desc = "Rising whistle over 0.4s. Gives the target a chance to react.",
    },
    gun_fire = {
        group = "COMBAT",
        range = 220,
        volume = 1.0,
        soundId = "",
        desc = "Sharp crack, long slap-back. Everyone knows roughly where.",
    },
    gun_pickup = {
        group = "COMBAT",
        range = 25,
        volume = 0.7,
        soundId = "",
        desc = "Metallic scrape and hammer cock. Signals a hero nearby.",
    },
    misfire_death = {
        group = "COMBAT",
        volume = 0.9,
        soundId = "",
        desc = "Reverse cymbal into silence. The sheriff knows what they did.",
    },

    -- EVIDENCE
    body_drop = {
        group = "EVIDENCE",
        range = 60,
        volume = 0.8,
        soundId = "",
        desc = "Soft collapse, then a beat of nothing.",
    },
    examine_start = {
        group = "EVIDENCE",
        range = 15,
        volume = 0.5,
        soundId = "",
        desc = "Paper rustle under the 1.5s channel. Investigating is public.",
    },
    clue_found = {
        group = "EVIDENCE",
        volume = 0.7,
        soundId = "",
        desc = "Three ascending marimba notes, one per clue line.",
    },
    trail_cold = {
        group = "EVIDENCE",
        volume = 0.6,
        soundId = "",
        desc = "A single flat low tone.",
    },
    body_drag = {
        group = "EVIDENCE",
        range = 35,
        volume = 0.9,
        soundId = "",
        desc = "Continuous scrape. Deliberately loud.",
    },

    -- EVENTS & META
    lights_out = {
        group = "EVENTS",
        volume = 0.9,
        soundId = "",
        desc = "Power-down whine over 1.2s, then room tone drops to almost nothing.",
    },
    power_surge = {
        group = "EVENTS",
        volume = 0.8,
        soundId = "",
        desc = "Electrical arcing, irregular. Never loops cleanly.",
    },
    lockdown = {
        group = "EVENTS",
        range = 80,
        twoD = true,
        volume = 0.9,
        soundId = "",
        desc = "Four bolts throwing in sequence, each at its real door position.",
    },
    crate_spin = {
        group = "META",
        volume = 0.6,
        soundId = "",
        desc = "Ratcheting tick that slows with the reel; pitch rises on the last three.",
    },
    crate_godly = {
        group = "META",
        volume = 0.9,
        soundId = "",
        desc = "Held choral chord with a bell. Legendary and Godly only.",
    },
    trade_complete = {
        group = "META",
        volume = 0.6,
        soundId = "",
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
