-- Who plays the next round. Each player chooses in the lobby to play now
-- (NPCs fill a quiet server) or to wait for a round of real players. Pure, so
-- RoundService decides with it and the lobby countdown mirrors it exactly.
local Lobby = {}

export type Plan = {
    start: boolean, -- a round starts when intermission ends
    full: boolean, -- enough real players: everyone plays, nobody waits
    npcs: number, -- NPC seats in the round
}

-- humans: everyone in the lobby; ready: those who chose to play now
function Lobby.Plan(
    humans: number,
    ready: number,
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
    -- Players who chose to wait sit this one out in the lobby
    local npcs = math.max(0, fillTo - ready)
    return { start = ready + npcs >= minPlayers, full = false, npcs = npcs }
end

return Lobby
