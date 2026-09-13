--!strict
-- Every client -> server remote goes through here (Handbook §06 · Remote spam).
-- A ceiling per player across every remote, and a tighter one per remote from
-- Config.REMOTE_LIMITS. Over-limit calls are rejected silently; sustained
-- abuse of either kicks. Handlers never learn about the limiter and never
-- tell the client why a call failed.
local Players = game:GetService("Players")
local Config = require(game.ReplicatedStorage.Shared.Config)
local RateLimiter = require(game.ReplicatedStorage.Shared.RateLimiter)
local Remotes = game.ReplicatedStorage.Remotes

local RemoteGuard = {}
local PER_REMOTE: { [string]: number } = Config.REMOTE_LIMITS :: any

local function newLimiter(perSec: number): RateLimiter.RateLimiter
    return RateLimiter.new(perSec, Config.REMOTE_STRIKES_TO_KICK, Config.REMOTE_STRIKE_WINDOW)
end

local global = newLimiter(Config.REMOTE_CALLS_PER_SEC)
local limiters: { RateLimiter.RateLimiter } = { global }

-- A flood arrives as hundreds of queued calls, and the limiter keeps saying
-- "kick" for every one of them. Kick the player once and drop the rest, or the
-- log fills with identical disconnect lines and buries everything else.
local kicked: { [Player]: boolean } = {}

function RemoteGuard.Connect(remoteName: string, handler: (Player, ...any) -> ())
    local remote = Remotes:FindFirstChild(remoteName) :: RemoteEvent
    assert(remote, "RemoteGuard: no remote named " .. remoteName)
    local perSec = PER_REMOTE[remoteName]
    local own = if perSec then newLimiter(perSec) else nil
    if own then
        table.insert(limiters, own)
    end
    remote.OnServerEvent:Connect(function(plr, ...)
        local now = os.clock()
        local allowed, kick = global:Hit(plr, now)
        if allowed and own then
            allowed, kick = own:Hit(plr, now)
        end
        if kick then
            if not kicked[plr] then
                kicked[plr] = true
                plr:Kick("Disconnected.")
            end
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
    kicked[plr] = nil
    for _, limiter in limiters do
        limiter:Remove(plr)
    end
end)

return RemoteGuard
