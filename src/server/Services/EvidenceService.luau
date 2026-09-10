local Config = require(game.ReplicatedStorage.Shared.Config)
local Remotes = game.ReplicatedStorage.Remotes
local EventService = require(script.Parent.EventService)
local AudioService = require(script.Parent.AudioService)
local DataService = require(script.Parent.DataService)
local Analytics = require(script.Parent.Analytics)

local EvidenceService = {}
local bodies = {} -- [Model] = clueData
local channeling = {} -- [Player] = true while a 1.5s examine is running
local round: any = nil -- RoundService, handed over by BindRound

function EvidenceService:BindRound(roundService)
    round = roundService
end

local DIRS =
    { "north", "north-east", "east", "south-east", "south", "south-west", "west", "north-west" }

local FIBRES = {
    "dark grey wool",
    "navy cotton",
    "black leather",
    "rust-red flannel",
    "pale linen",
    "oiled canvas",
}

local function compass(from: Vector3, to: Vector3): string
    local d = to - from
    local deg = math.deg(math.atan2(d.X, -d.Z)) % 360
    return DIRS[(math.floor((deg + 22.5) / 45) % 8) + 1]
end

function EvidenceService:ColourBandOf(plr: Player): string
    -- Deterministic per player so two clues never contradict
    local seed = 0
    for i = 1, #plr.Name do
        seed += string.byte(plr.Name, i)
    end
    return FIBRES[(seed % #FIBRES) + 1]
end

function EvidenceService:HadLineOfSight(victim: Player, killer: Player): boolean
    -- Approximation: was the killer roughly in front of the victim?
    local vc, kc = victim.Character, killer.Character
    if not (vc and kc) then
        return false
    end
    local facing = vc:GetPivot().LookVector
    local toKiller = (kc:GetPivot().Position - vc:GetPivot().Position).Unit
    return facing:Dot(toKiller) > 0.55
end

function EvidenceService:DropBody(victim: Player, killer: Player)
    local char = victim.Character
    local roundFolder = workspace:FindFirstChild("Round")
    if not (char and roundFolder) then
        return
    end
    local pos = char:GetPivot().Position
    local killerPos = killer.Character and killer.Character:GetPivot().Position or pos

    local model = game.ServerStorage.BodyTemplate:Clone()
    model:PivotTo(CFrame.new(pos))
    model:AddTag("Body")
    model.Parent = roundFolder

    -- Facts the client is NEVER told until it earns them
    bodies[model] = {
        victim = victim.DisplayName,
        killer = killer.Name,
        dir = compass(killerPos, pos),
        fibre = self:ColourBandOf(killer),
        at = os.clock(),
        sawKiller = killer ~= victim and self:HadLineOfSight(victim, killer),
        examined = false,
    }
    Remotes.BodyDropped:FireAllClients(model, pos)
    AudioService:Emit("body_drop", pos)
end

local function inRange(plr: Player, model: Model): boolean
    local char = plr.Character
    return char ~= nil
        and model.Parent ~= nil
        and (char:GetPivot().Position - model:GetPivot().Position).Magnitude
            <= Config.EXAMINE_RANGE
end

function EvidenceService:Examine(plr: Player, model: Instance)
    local data = bodies[model]
    if not data or data.examined or channeling[plr] then
        return
    end
    local RoundService = round
    if not RoundService:IsAlive(plr) then
        return
    end
    -- Range check before anything is sent back: clues, "cold", even the sound
    if not inRange(plr, model :: Model) then
        return
    end

    channeling[plr] = true
    AudioService:Emit("examine_start", (model :: Model):GetPivot().Position)
    task.wait(Config.EXAMINE_TIME)
    channeling[plr] = nil

    -- Re-validate after the channel: they may have died, walked off, or lost the race
    if
        bodies[model] ~= data
        or data.examined
        or not RoundService:IsAlive(plr)
        or not inRange(plr, model :: Model)
    then
        return
    end

    -- Clues cannot be read in the dark. This is the murderer's window.
    local age = os.clock() - data.at
    if EventService:IsDark() or age > Config.BODY_CLUE_WINDOW then
        Remotes.Clue:FireClient(plr, { cold = true })
        return
    end

    data.examined = true
    local clues = {
        { kind = "direction", text = ("%s was struck from the %s."):format(data.victim, data.dir) },
        { kind = "fibre", text = ("Fibre trace: %s."):format(data.fibre) },
        { kind = "time", text = ("Time of death: %ds ago."):format(math.floor(age)) },
    }
    if data.sawKiller then
        table.insert(clues, {
            kind = "witness",
            text = ("Partial name on the lips: %s…"):format(data.killer:sub(1, 2)),
        })
    end
    Remotes.Clue:FireClient(plr, clues)

    RoundService.clueCounts[plr] = (RoundService.clueCounts[plr] or 0) + 1
    require(script.Parent.EconomyService):Grant(plr, Config.EXAMINE_REWARD, 0, "examine")
    local profile = DataService:Get(plr)
    Analytics.EvidenceExamined(plr, #clues, age, profile and profile.rank or 0)
end

function EvidenceService:Clear()
    bodies = {}
    channeling = {}
end

return EvidenceService
