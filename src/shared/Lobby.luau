--!strict
-- Who plays the next round. Each player chooses in the lobby to play now
-- (NPCs fill a quiet server) or to wait for a round of real players, and
-- until they choose they are undecided. Pure, so RoundService decides with it
-- and the lobby countdown mirrors it exactly.
local Lobby = {}

export type Plan = {
    start: boolean, -- a round starts when the countdown ends
    full: boolean, -- enough real players: everyone plays, nobody waits
    npcs: number, -- NPC seats in the round
}

-- humans: everyone in the lobby; ready: chose PLAY NOW; waiting: chose WAIT.
-- The rest have not chosen. Nobody starts a round they did not ask for, so
-- the countdown only runs once someone has pressed PLAY NOW - a fresh join
-- sees the choice first, not a timer already ticking toward an NPC round.
-- But a player who has not chosen when a round others asked for starts is
-- in it, not left behind in the lobby: only WAIT sits a round out.
function Lobby.Plan(
    humans: number,
    ready: number,
    waiting: number,
    minPlayers: number,
    fillTo: number,
    botsEnabled: boolean
): Plan
    if humans >= minPlayers then
        return { start = true, full = true, npcs = 0 }
    end
    if not botsEnabled or ready < 1 then
        return { start = false, full = false, npcs = 0 }
    end
    local playing = humans - waiting
    local npcs = math.max(0, fillTo - playing)
    return { start = playing + npcs >= minPlayers, full = false, npcs = npcs }
end

return Lobby
