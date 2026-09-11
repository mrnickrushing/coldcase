-- A round participant is a Player or an NPC from BotService. NPCs are plain
-- tables carrying the few Player fields round code reads (Name, DisplayName,
-- UserId, Character), so anything that talks to a client, a profile or
-- analytics must ask first.
local Participant = {}

function Participant.IsBot(p: any): boolean
    return type(p) == "table" and p.IsBot == true
end

return Participant
