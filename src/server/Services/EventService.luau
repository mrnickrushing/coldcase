local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Config = require(game.ReplicatedStorage.Shared.Config)
local AudioService = require(script.Parent.AudioService)
local Remotes = game.ReplicatedStorage.Remotes

local EventService = {}
local active = nil
local lastFiredId: string? = nil

-- Captured once so Clear restores whatever the place was built with.
-- Vision radius and fog are drawn per client by VisionController; the server
-- only changes shared light levels.
local BASE = {
    Brightness = Lighting.Brightness,
    Ambient = Lighting.Ambient,
    OutdoorAmbient = Lighting.OutdoorAmbient,
    EnvironmentDiffuseScale = Lighting.EnvironmentDiffuseScale,
    ClockTime = Lighting.ClockTime,
}

-- Killing the lights means killing every source of it. On a daylit map the sun,
-- the sky and the outdoor ambient all have to go, or the blackout is not dark.
local function douse()
    Lighting.Brightness = 0
    Lighting.Ambient = Color3.fromRGB(8, 10, 14)
    Lighting.OutdoorAmbient = Color3.fromRGB(12, 14, 20)
    Lighting.EnvironmentDiffuseScale = 0
    Lighting.ClockTime = 0.2
end

local function relight()
    Lighting.Brightness = BASE.Brightness
    Lighting.Ambient = BASE.Ambient
    Lighting.OutdoorAmbient = BASE.OutdoorAmbient
    Lighting.EnvironmentDiffuseScale = BASE.EnvironmentDiffuseScale
    Lighting.ClockTime = BASE.ClockTime
end

-- One event per round. Chaos stops being an event when it is the weather.
-- `anywhere` events ignore the indoor/outdoor split. Lockdown is one of them:
-- every map builds LockdownDoor parts (the Pier has five) and MapPlan's
-- reachability test proves a shut door seals nobody in, on every map. Without
-- it the Pier had a pool of two, half of which was a blackout.
local EVENTS = {
    { id = "LIGHTS_OUT", weight = 30, duration = Config.LIGHTS_OUT_DUR, indoor = true },
    { id = "POWER_SURGE", weight = 25, duration = Config.LIGHTS_OUT_DUR, anywhere = true },
    { id = "LOCKDOWN", weight = 20, duration = Config.LOCKDOWN_DUR, anywhere = true },
    { id = "FOG_BANK", weight = 25, duration = Config.FOG_DUR, indoor = false },
}

local function lockdownDoors()
    local out = {}
    local round = workspace:FindFirstChild("Round")
    if round then
        for _, d in round:GetDescendants() do
            if d:IsA("BasePart") and d:HasTag("LockdownDoor") then
                table.insert(out, d)
            end
        end
    end
    return out
end

-- The map's lamps (BuildMaps tags them MapLight) go dark with the room
local function setMapLights(on: boolean)
    for _, lamp in CollectionService:GetTagged("MapLight") do
        if lamp:IsA("BasePart") and lamp:IsDescendantOf(workspace) then
            local light = lamp:FindFirstChildOfClass("PointLight")
            if light then
                light.Enabled = on
            end
            lamp.Material = on and Enum.Material.Neon or Enum.Material.SmoothPlastic
        end
    end
end

function EventService:FireWeighted(mapIsIndoor: boolean)
    local pool = {}
    for _, e in EVENTS do
        if e.anywhere or e.indoor == mapIsIndoor then
            table.insert(pool, e)
        end
    end
    local total = 0
    for _, e in pool do
        total += e.weight
    end
    local n = math.random() * total
    local chosen = pool[1]
    for _, e in pool do
        n -= e.weight
        if n <= 0 then
            chosen = e
            break
        end
    end
    self:Fire(chosen)
end

function EventService:Fire(event)
    if active then
        return
    end
    active = event
    lastFiredId = event.id
    Remotes.EventFired:FireAllClients(event.id, event.duration)

    if event.id == "LIGHTS_OUT" then
        AudioService:Play2D(nil, "lights_out")
        douse()
        setMapLights(false)
    elseif event.id == "POWER_SURGE" then
        AudioService:Play2D(nil, "power_surge")
        task.spawn(function()
            douse()
            local t0 = os.clock()
            while os.clock() - t0 < event.duration and active == event do
                local on = math.random() > 0.5
                -- The sun stays down; only the lights stutter
                Lighting.Brightness = if on then BASE.Brightness else 0
                Lighting.Ambient = if on then BASE.Ambient else Color3.fromRGB(8, 10, 14)
                setMapLights(on)
                task.wait(math.random(4, 22) / 100)
            end
        end)
    elseif event.id == "LOCKDOWN" then
        AudioService:Play2D(nil, "lockdown")
        for i, door in lockdownDoors() do
            task.delay((i - 1) * 0.2, function()
                if active ~= event then
                    return
                end
                door.CanCollide = true
                door.Transparency = 0
                AudioService:Emit("lockdown", door.Position)
            end)
        end
    end

    task.delay(event.duration, function()
        if active == event then
            self:Clear()
        end
    end)
end

function EventService:Clear()
    if not active then
        return
    end
    for _, door in lockdownDoors() do
        door.CanCollide = false
        door.Transparency = 1
    end
    active = nil
    relight()
    setMapLights(true)
    Remotes.EventFired:FireAllClients("CLEAR", 0)
end

function EventService:IsDark(): boolean
    return active ~= nil and (active.id == "LIGHTS_OUT" or active.id == "POWER_SURGE")
end

-- The event that fired this round, for round_complete analytics. Resets it.
function EventService:TakeRoundEvent(): string?
    local id = lastFiredId
    lastFiredId = nil
    return id
end

return EventService
