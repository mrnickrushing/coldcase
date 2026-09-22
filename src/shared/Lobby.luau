--!strict
-- Who plays the next round. Everyone waits for real players until they say
-- otherwise: a family joins one at a time, and nobody should be swept into
-- a round before the rest are in. Once the group is there, each presses
-- PLAY NOW (NPCs fill the seats), and the round is exactly those people.
-- Pure, so RoundService decides with it and the lobby countdown mirrors it.
local Lobby = {}

-- Where the lobby floor stands. The maps load at the origin, the largest of
-- them 243 studs across, so the lobby lives far down -Z where no map can
-- reach it. default.project.json places the part there; BuildLobby moves it
-- back if a saved place has it anywhere else. One saved place had it dragged
-- to the origin, and every round then loaded a mansion around the lobby: its
-- brick walls stood through the cellar and its floor sat a stud above the
-- cellar's, reading as brick half walls and a floor that had sunk.
Lobby.FLOOR = { x = 0, y = -1, z = -900 }

export type Plan = {
    start: boolean, -- a round starts when the countdown ends
    full: boolean, -- enough real players: everyone plays, nobody waits
    npcs: number, -- NPC seats in the round
}

-- humans: everyone in the lobby; ready: those who pressed PLAY NOW. The
-- countdown runs only once someone has, and only they play; everyone else
-- keeps waiting in the lobby.
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
    local npcs = math.max(0, fillTo - ready)
    return { start = ready + npcs >= minPlayers, full = false, npcs = npcs }
end

return Lobby
