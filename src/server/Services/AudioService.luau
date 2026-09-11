-- Server side of the sound spec (Handbook §04).
-- Positional cues are sent only to players inside the cue's range. Parenting
-- a replicated Sound at the source would hand an exploiter a live map of every
-- knife swing — role ESP through the audio channel.
local Players = game:GetService("Players")
local SoundCues = require(game.ReplicatedStorage.Shared.SoundCues)
local Remotes = game.ReplicatedStorage.Remotes
local Participant = require(script.Parent.Participant)

local AudioService = {}
local RANGE_SLACK = 1.1

function AudioService:Emit(cueId: string, position: Vector3)
    local cue = SoundCues.cues[cueId]
    if not cue then
        return
    end
    if not cue.range then
        Remotes.PlayCue:FireAllClients(cueId)
        return
    end
    local reach = cue.range * RANGE_SLACK
    for _, plr in Players:GetPlayers() do
        local char = plr.Character
        if char and (char:GetPivot().Position - position).Magnitude <= reach then
            Remotes.PlayCue:FireClient(plr, cueId, position)
        end
    end
end

function AudioService:Play2D(plr: Player?, cueId: string, pitch: number?)
    if plr then
        if Participant.IsBot(plr) then
            return
        end
        Remotes.PlayCue:FireClient(plr, cueId, nil, pitch)
    else
        Remotes.PlayCue:FireAllClients(cueId, nil, pitch)
    end
end

return AudioService
