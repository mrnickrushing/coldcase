-- Dead participants follow the living. Two minutes staring at your own body
-- is the biggest quit risk in a round game. The client owns the camera; the
-- server only says who is left to watch. Who is alive is public already (the
-- HUD shows the count and bodies drop in view), so the list gives nothing away.
local Players = game:GetService("Players")
local Remotes = game.ReplicatedStorage.Remotes

local SpectatorService = {}
local watching: { [Player]: boolean } = {}

function SpectatorService:Enter(plr: Player, targets: { string })
    if plr.Parent ~= Players then
        return
    end
    watching[plr] = true
    Remotes.Spectate:FireClient(plr, "enter", targets)
end

function SpectatorService:Exit(plr: Player)
    if not watching[plr] then
        return
    end
    watching[plr] = nil
    Remotes.Spectate:FireClient(plr, "exit")
end

-- Keep every spectator's list current as people die and are revived
function SpectatorService:Broadcast(targets: { string })
    for plr in watching do
        Remotes.Spectate:FireClient(plr, "targets", targets)
    end
end

function SpectatorService:Send(plr: Player, targets: { string })
    if watching[plr] then
        Remotes.Spectate:FireClient(plr, "targets", targets)
    end
end

function SpectatorService:IsSpectating(plr: Player): boolean
    return watching[plr] == true
end

function SpectatorService:Reset()
    for plr in watching do
        if plr.Parent == Players then
            Remotes.Spectate:FireClient(plr, "exit")
        end
    end
    watching = {}
end

Players.PlayerRemoving:Connect(function(plr)
    watching[plr] = nil
end)

return SpectatorService
