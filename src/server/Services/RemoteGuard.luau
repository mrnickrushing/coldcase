-- Every client -> server remote goes through here (Handbook §06 · Remote spam).
-- 20 calls/sec per player across all remotes, rejected silently; sustained
-- abuse kicks. Handlers never learn about the limiter and never tell the
-- client why a call failed.
local Players = game:GetService("Players")
local Config = require(game.ReplicatedStorage.Shared.Config)
local RateLimiter = require(game.ReplicatedStorage.Shared.RateLimiter)
local Remotes = game.ReplicatedStorage.Remotes

local RemoteGuard = {}
local limiter = RateLimiter.new(
    Config.REMOTE_CALLS_PER_SEC,
    Config.REMOTE_STRIKES_TO_KICK,
    Config.REMOTE_STRIKE_WINDOW
)

function RemoteGuard.Connect(remoteName: string, handler: (Player, ...any) -> ())
    local remote = Remotes:FindFirstChild(remoteName) :: RemoteEvent
    assert(remote, "RemoteGuard: no remote named " .. remoteName)
    remote.OnServerEvent:Connect(function(plr, ...)
        local allowed, kick = limiter:Hit(plr, os.clock())
        if kick then
            plr:Kick("Disconnected.")
            return
        end
        if not allowed then
            return
        end
        handler(plr, ...)
    end)
end

-- Rejects NaN and infinite components, which slip past typeof() checks
function RemoteGuard.IsFiniteVector(v: any): boolean
    if typeof(v) ~= "Vector3" then
        return false
    end
    for _, n in { v.X, v.Y, v.Z } do
        if n ~= n or n == math.huge or n == -math.huge then
            return false
        end
    end
    return true
end

Players.PlayerRemoving:Connect(function(plr)
    limiter:Remove(plr)
end)

return RemoteGuard
