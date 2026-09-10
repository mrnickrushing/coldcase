-- Plays the handbook's twenty-two cues. Server-emitted cues arrive on
-- PlayCue (already range-filtered); the rest are triggered locally from
-- events this client is entitled to know about.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local SoundCues = require(Shared.SoundCues)
local ClientState = require(script.Parent.Parent.ClientState)

local SoundController = {}
local warned = {}

local function build(cueId: string, pitch: number?, volumeScale: number?): Sound?
    local cue = SoundCues.cues[cueId]
    if not cue then
        return nil
    end
    if cue.soundId == "" then
        if RunService:IsStudio() and not warned[cueId] then
            warned[cueId] = true
            print("[Sound] no asset for cue", cueId)
        end
        return nil
    end
    local s = Instance.new("Sound")
    s.SoundId = cue.soundId
    s.Volume = cue.volume * (volumeScale or 1)
    s.PlaybackSpeed = pitch or 1
    return s
end

function SoundController.Play(
    cueId: string,
    position: Vector3?,
    pitch: number?,
    volumeScale: number?
)
    local s = build(cueId, pitch, volumeScale)
    if not s then
        return
    end
    local cue = SoundCues.cues[cueId]
    if position and cue.range then
        local holder = Instance.new("Attachment")
        holder.WorldPosition = position
        holder.Parent = workspace.Terrain
        s.RollOffMode = Enum.RollOffMode.InverseTapered
        s.RollOffMinDistance = 8
        s.RollOffMaxDistance = cue.range
        s.Parent = holder
        s.Ended:Connect(function()
            holder:Destroy()
        end)
        s:Play()
    else
        s.Parent = SoundService
        s.Ended:Connect(function()
            s:Destroy()
        end)
        s:Play()
    end
end

Remotes.PlayCue.OnClientEvent:Connect(function(cueId, position, pitch)
    SoundController.Play(cueId, position, pitch)
end)

---------------------------------------------------------------- local triggers
Remotes.RoleAssigned.OnClientEvent:Connect(function(role)
    SoundController.Play("round_reveal", nil, SoundCues.ROLE_PITCH[role])
end)

Remotes.Clue.OnClientEvent:Connect(function(clues)
    SoundController.Play(clues.cold and "trail_cold" or "clue_found")
end)

Remotes.RoundOver.OnClientEvent:Connect(function(winner)
    local role = ClientState.role
    if not role then
        return -- spectators get no verdict sting
    end
    local mySide = role == "murderer" and "murderer" or "innocents"
    SoundController.Play(mySide == winner and "round_win" or "round_lose")
end)

Remotes.CrateResult.OnClientEvent:Connect(function(result)
    if result.announce then
        return
    end
    SoundController.Play("crate_spin")
    if result.rarity == "Legendary" or result.rarity == "Godly" then
        task.delay(1.2, SoundController.Play, "crate_godly")
    end
end)

Remotes.TradeComplete.OnClientEvent:Connect(function()
    SoundController.Play("trade_complete")
end)

-- round_start on ACTIVE; timer_30 ticks once a second, fading in over the last 30s
local lastTick = -1
ReplicatedStorage:GetAttributeChangedSignal("RoundState"):Connect(function()
    if ClientState.GetRoundState() == "ACTIVE" and ClientState.role then
        SoundController.Play("round_start")
    end
end)
RunService.Heartbeat:Connect(function()
    if ClientState.GetRoundState() ~= "ACTIVE" or not ClientState.role then
        return
    end
    local left = (ReplicatedStorage:GetAttribute("RoundEnds") or 0) - workspace:GetServerTimeNow()
    local whole = math.ceil(left)
    if whole <= 30 and whole > 0 and whole ~= lastTick then
        lastTick = whole
        SoundController.Play("timer_30", nil, 1, 1 - (whole - 1) / 30)
    end
end)

Players.LocalPlayer.CharacterAdded:Connect(function()
    lastTick = -1
end)

return SoundController
