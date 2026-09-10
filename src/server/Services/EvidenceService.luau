local Players = game:GetService("Players")
local Shared = game.ReplicatedStorage.Shared
local Config = require(Shared.Config)
local FibreBands = require(Shared.FibreBands)
local Remotes = game.ReplicatedStorage.Remotes
local EventService = require(script.Parent.EventService)
local AudioService = require(script.Parent.AudioService)
local DataService = require(script.Parent.DataService)
local Analytics = require(script.Parent.Analytics)

local EvidenceService = {}
local bodies = {} -- [Model] = clueData
local channeling = {} -- [Player] = true while a 1.5s examine is running
local round: any = nil -- RoundService, handed over by BindRound

-- Who has seen whom. `since` is when the current unbroken sightline began;
-- `qualified` is the last moment that sightline had lasted WITNESS_LOS_TIME.
type Sight = { since: number?, qualified: number? }
local sight: { [Player]: { [Player]: Sight } } = {}

function EvidenceService:BindRound(roundService)
    round = roundService
end

local DIRS =
    { "north", "north-east", "east", "south-east", "south", "south-west", "west", "north-west" }

local function compass(from: Vector3, to: Vector3): string
    local d = to - from
    local deg = math.deg(math.atan2(d.X, -d.Z)) % 360
    return DIRS[(math.floor((deg + 22.5) / 45) % 8) + 1]
end

-- The killer's actual torso colour, bucketed into a broad band. Narrows,
-- never names. (Shirt textures are not readable, so this is body colour.)
function EvidenceService:ColourBandOf(plr: Player): string
    local char = plr.Character
    local torso = char and (char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso"))
    local colour = if torso and torso:IsA("BasePart")
        then torso.Color
        else Color3.fromRGB(128, 128, 128)
    return FibreBands.Describe(colour:ToHSV())
end

---------------------------------------------------------------- Sightlines
-- Called every SIGHTLINE_SAMPLE seconds by RoundService with the living
-- participants. A witness clue needs a real, unbroken raycast sightline, not
-- a facing check.
function EvidenceService:SampleSightlines(players: { Player }, now: number)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    for _, viewer in players do
        local vc = viewer.Character
        local head = vc and vc:FindFirstChild("Head")
        if not (head and head:IsA("BasePart")) then
            continue
        end
        local mine = sight[viewer]
        if not mine then
            mine = {}
            sight[viewer] = mine
        end
        for _, other in players do
            if other == viewer then
                continue
            end
            local st = mine[other]
            if not st then
                st = {}
                mine[other] = st
            end

            local seen = false
            local oc = other.Character
            if oc then
                local to = oc:GetPivot().Position - head.Position
                local dist = to.Magnitude
                if
                    dist > 0
                    and dist <= Config.SIGHTLINE_RANGE
                    and head.CFrame.LookVector:Dot(to / dist) >= 0.5
                then
                    params.FilterDescendantsInstances = { vc :: Model, oc }
                    seen = workspace:Raycast(head.Position, to, params) == nil
                end
            end

            if seen then
                st.since = st.since or now
                if now - (st.since :: number) >= Config.WITNESS_LOS_TIME then
                    st.qualified = now
                end
            else
                st.since = nil
            end
        end
    end
end

function EvidenceService:ResetSightlines()
    sight = {}
end

-- Did the victim watch the killer for a full second, recently enough to matter?
function EvidenceService:HadLineOfSight(victim: Player, killer: Player): boolean
    local st = sight[victim] and sight[victim][killer]
    return st ~= nil and st.qualified ~= nil and os.clock() - st.qualified <= Config.WITNESS_WINDOW
end

---------------------------------------------------------------- Bodies
function EvidenceService:DropBody(victim: Player, killer: Player)
    local char = victim.Character
    local roundFolder = workspace:FindFirstChild("Round")
    if not (char and roundFolder) then
        return
    end
    local pos = char:GetPivot().Position
    local killerPos = killer.Character and killer.Character:GetPivot().Position or pos

    local model = game.ServerStorage.BodyTemplate:Clone()
    model:PivotTo(CFrame.new(pos - Vector3.new(0, 2.5, 0)))
    model:AddTag("Body")
    model.Parent = roundFolder

    -- Facts the client is NEVER told until it earns them
    bodies[model] = {
        victim = victim.DisplayName,
        victimPlayer = victim,
        killer = killer.Name,
        dir = compass(killerPos, pos),
        fibre = self:ColourBandOf(killer),
        at = os.clock(),
        sawKiller = killer ~= victim and self:HadLineOfSight(victim, killer),
        examined = false,
        draggedBy = nil,
    }
    Remotes.BodyDropped:FireAllClients(model, pos)
    AudioService:Emit("body_drop", pos)
end

function EvidenceService:GetBody(model: any)
    return bodies[model]
end

function EvidenceService:RemoveBody(model: Instance)
    bodies[model] = nil
    model:Destroy()
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
    if not round:IsAlive(plr) then
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
        or not round:IsAlive(plr)
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

    round.clueCounts[plr] = (round.clueCounts[plr] or 0) + 1
    require(script.Parent.EconomyService):Grant(plr, Config.EXAMINE_REWARD, 0, "examine")
    local profile = DataService:Get(plr)
    Analytics.EvidenceExamined(plr, #clues, age, profile and profile.rank or 0)
end

function EvidenceService:Clear()
    bodies = {}
    channeling = {}
    sight = {}
end

Players.PlayerRemoving:Connect(function(plr)
    sight[plr] = nil
    for _, mine in sight do
        mine[plr] = nil
    end
end)

return EvidenceService
