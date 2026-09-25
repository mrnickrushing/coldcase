--!strict
-- Game modes. Each round runs one; Classic is the default. The flags here are
-- read by the services that branch on the current mode (RoundService picks it
-- and publishes it as the ReplicatedStorage "Mode" attribute).
local Modes = {}

export type Def = {
    name: string,
    blurb: string,
    dark: boolean?, -- dim the round and cut vision the whole time
    noMedic: boolean?, -- the medic role is not dealt
    clueWindow: number?, -- seconds a body's clues stay readable (else Config)
}

Modes.DEFS = {
    classic = { name = "Classic", blurb = "The standard investigation." },
    hardcore = {
        name = "Hardcore",
        blurb = "Lights low, no medic, and clues go cold fast.",
        dark = true,
        noMedic = true,
        clueWindow = 8,
    },
} :: { [string]: Def }

-- The special modes that rotate in between Classic rounds, in order. New modes
-- join here as they ship.
Modes.ROTATION = { "hardcore" }

function Modes.Get(id: string?): Def
    return (id ~= nil and Modes.DEFS[id]) or Modes.DEFS.classic
end

return Modes
