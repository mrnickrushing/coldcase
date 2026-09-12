-- StarterPlayerScripts/Controllers/VisionController
-- Vision radius, name-tag rules and the Last Call outline. All visual: the
-- server never trusts any of it, and an exploiter removing the fog gains
-- nothing the server would accept.
--
-- The radius is real distance fog (Lighting.FogStart/FogEnd, set locally),
-- so anything past it is actually hidden. Note: an Atmosphere in Lighting
-- disables legacy fog, so the place must not have one.
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Theme = require(Shared.Theme)
local ClientState = require(script.Parent.Parent.ClientState)

local plr = Players.LocalPlayer
local VisionController = {}

local DARK = Color3.fromHex("05070a") -- Lights Out: the room really goes black
local NIGHT = Color3.fromHex("c6d2dc") -- every other moment: bright haze, never a void
local FOG_GREY = Color3.fromHex("6f7883")
local BASE = { start = Lighting.FogStart, finish = Lighting.FogEnd, colour = Lighting.FogColor }

local event: string? = nil
local lastCallNames: { [string]: boolean } = {}
local radius = Config.VISION_NORMAL
local surgeTarget, nextFlicker = Config.VISION_NORMAL, 0
local applied = false

if Lighting:FindFirstChildOfClass("Atmosphere") then
    warn("[ColdCase] Lighting has an Atmosphere; it disables the fog that draws vision radius")
end

Remotes.EventFired.OnClientEvent:Connect(function(id: string, _duration, extra)
    if id == "CLEAR" then
        event = nil
    elseif id == "LAST_CALL" then
        lastCallNames = {}
        for _, name in extra or {} do
            lastCallNames[name] = true
        end
    else
        event = id
    end
end)

ReplicatedStorage:GetAttributeChangedSignal("RoundState"):Connect(function()
    if ClientState.GetRoundState() ~= "ACTIVE" then
        event = nil
        lastCallNames = {}
    end
end)

local function inRound(): boolean
    return ClientState.GetRoundState() == "ACTIVE" and ClientState.role ~= nil
end

local function targetRadius(): number
    if event == "LIGHTS_OUT" then
        return Config.VISION_DARK
    elseif event == "POWER_SURGE" then
        -- Flickers between the surge radius and full, never on a clean rhythm
        if os.clock() >= nextFlicker then
            surgeTarget = math.random() > 0.5 and Config.VISION_SURGE or Config.VISION_NORMAL
            nextFlicker = os.clock() + math.random(8, 30) / 100
        end
        return surgeTarget
    end
    return Config.VISION_NORMAL
end

local function outline(char: Model, on: boolean)
    local hl = char:FindFirstChild("LastCallOutline") :: Highlight?
    if on and not hl then
        local h = Instance.new("Highlight")
        h.Name = "LastCallOutline"
        h.FillTransparency = 1
        h.OutlineColor = Theme.ROLE.murderer
        h.OutlineTransparency = 0.55 -- faint, through walls
        h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        h.Parent = char
    elseif not on and hl then
        hl:Destroy()
    end
end

RunService.RenderStepped:Connect(function(dt)
    local active = inRound()
    local myChar = plr.Character

    if active then
        local target = targetRadius()
        if event == "POWER_SURGE" then
            radius = target
        else
            radius += (target - radius) * math.min(1, dt * 4)
        end
        Lighting.FogColor = if event == "FOG_BANK"
            then FOG_GREY
            elseif event == "LIGHTS_OUT" then DARK
            else NIGHT
        Lighting.FogStart = radius * 0.75
        Lighting.FogEnd = radius
        applied = true
    elseif applied then
        Lighting.FogStart, Lighting.FogEnd, Lighting.FogColor = BASE.start, BASE.finish, BASE.colour
        radius = Config.VISION_NORMAL
        applied = false
    end

    -- Spectators measure from whoever they are watching
    local camera = workspace.CurrentCamera
    local subject = camera and camera.CameraSubject
    local focus = if subject and subject:IsA("Humanoid") then subject.Parent else myChar
    local myPos = if focus and focus:IsA("Model") then focus:GetPivot().Position else nil
    local others: { { name: string, char: Model } } = {}
    for _, other in Players:GetPlayers() do
        if other ~= plr and other.Character then
            table.insert(others, { name = other.Name, char = other.Character })
        end
    end
    for _, model in CollectionService:GetTagged("BotCharacter") do
        if model:IsA("Model") then
            table.insert(
                others,
                { name = model:GetAttribute("BotName") or model.Name, char = model }
            )
        end
    end
    for _, other in others do
        local char = other.char
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            if active and myPos then
                local d = (char:GetPivot().Position - myPos).Magnitude
                -- Nothing past the vision radius shows a name; in Fog Bank you
                -- see a shape, not a person, beyond 40 studs
                local visible = d <= radius
                    and not (event == "FOG_BANK" and d > Config.FOG_NAMETAG_RANGE)
                hum.DisplayDistanceType = visible and Enum.HumanoidDisplayDistanceType.Viewer
                    or Enum.HumanoidDisplayDistanceType.None
                hum.NameDisplayDistance = radius
            else
                hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
                hum.NameDisplayDistance = 100
            end
        end
        outline(char, active and lastCallNames[other.name] == true)
    end
end)

return VisionController
