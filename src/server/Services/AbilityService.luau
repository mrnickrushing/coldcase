-- Medic revive and body dragging (Design Bible · Roles, Counterplay).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Config = require(game.ReplicatedStorage.Shared.Config)
local Remotes = game.ReplicatedStorage.Remotes
local RoleService = require(script.Parent.RoleService)
local EvidenceService = require(script.Parent.EvidenceService)
local EconomyService = require(script.Parent.EconomyService)
local AudioService = require(script.Parent.AudioService)
local Participant = require(script.Parent.Participant)

local AbilityService = {}
local round: any = nil -- RoundService, handed over by BindRound
local reviveUsed: { [Player]: boolean } = {}
local channeling: { [Player]: boolean } = {}
local pendingDrag: { [Player]: Instance } = {}
local dragging: { [Player]: { model: Model, body: any, conn: RBXScriptConnection } } = {}

function AbilityService:BindRound(roundService)
    round = roundService
end

local function position(plr: Player): Vector3?
    local char = plr.Character
    return char and char:GetPivot().Position
end

local function near(plr: Player, model: Instance): boolean
    local here = position(plr)
    return here ~= nil
        and model.Parent ~= nil
        and (here - (model :: Model):GetPivot().Position).Magnitude <= Config.EXAMINE_RANGE
end

---------------------------------------------------------------- Revive
-- One revive per round, 3s channel, only on a body nobody has examined yet.
-- The channel breaks if the medic moves: standing still beside a body in a
-- room with a murderer is the whole cost of the ability.
function AbilityService:RequestRevive(plr: Player, model: Instance)
    if RoleService:Get(plr) ~= "medic" or reviveUsed[plr] or channeling[plr] then
        return
    end
    if not round:IsAlive(plr) then
        return
    end
    local body = EvidenceService:GetBody(model)
    if not body or body.examined or body.draggedBy then
        return
    end
    local victim = body.victimPlayer
    if
        not (victim and victim.Parent == Players and round:IsParticipant(victim))
        or Participant.IsBot(victim) -- an NPC has no player to bring back
        or not near(plr, model)
    then
        return
    end

    channeling[plr] = true
    Remotes.AbilityState:FireClient(plr, "revive_start", Config.REVIVE_CHANNEL)
    local start = position(plr) :: Vector3
    local t0 = os.clock()
    while os.clock() - t0 < Config.REVIVE_CHANNEL do
        task.wait(0.1)
        local here = position(plr)
        local broken = not round:IsAlive(plr)
            or not here
            or (here - start).Magnitude > Config.REVIVE_MOVE_TOLERANCE
            or EvidenceService:GetBody(model) ~= body
            or body.examined
            or body.draggedBy
            or victim.Parent ~= Players
        if broken then
            channeling[plr] = nil
            Remotes.AbilityState:FireClient(plr, "revive_failed", 0)
            return
        end
    end
    channeling[plr] = nil

    -- Spent only on success, so a broken channel can be tried again
    reviveUsed[plr] = true
    local spot = (model :: Model):GetPivot().Position
    EvidenceService:RemoveBody(model)
    victim:LoadCharacter()
    local char = victim.Character
    if char then
        char:PivotTo(CFrame.new(spot + Vector3.new(0, 3, 0)))
    end
    round:Revive(victim)
    Remotes.AbilityState:FireClient(plr, "revive_done", 0)
    Remotes.Notify:FireClient(victim, "You were revived.")
    EconomyService:Grant(plr, Config.REVIVE_COINS, Config.REVIVE_XP, "revive")
end

---------------------------------------------------------------- Drag
-- Hold for DRAG_TIME to take hold, then the body follows at reduced walk
-- speed. Slow, loud, and worth it.
function AbilityService:StartDrag(plr: Player, model: Instance)
    if pendingDrag[plr] or dragging[plr] or not round:IsAlive(plr) then
        return
    end
    local body = EvidenceService:GetBody(model)
    if not body or body.draggedBy or not near(plr, model) then
        return
    end

    pendingDrag[plr] = model
    Remotes.AbilityState:FireClient(plr, "drag_start", Config.DRAG_TIME)
    task.delay(Config.DRAG_TIME, function()
        if pendingDrag[plr] ~= model then
            return -- released before taking hold
        end
        pendingDrag[plr] = nil
        if
            not round:IsAlive(plr)
            or EvidenceService:GetBody(model) ~= body
            or body.draggedBy
            or not near(plr, model)
        then
            Remotes.AbilityState:FireClient(plr, "drag_stop", 0)
            return
        end

        local hum = (plr.Character :: Model):FindFirstChildOfClass("Humanoid")
        if hum then
            hum.WalkSpeed = Config.DRAG_WALKSPEED
        end
        body.draggedBy = plr

        local corpse = model :: Model
        local lastSound = 0
        local conn = RunService.Heartbeat:Connect(function()
            local char = plr.Character
            if not (char and round:IsAlive(plr) and corpse.Parent) then
                self:StopDrag(plr)
                return
            end
            local pivot = char:GetPivot()
            local spot = pivot.Position - pivot.LookVector * 4 - Vector3.new(0, 2.5, 0)
            corpse:PivotTo(CFrame.new(spot) * pivot.Rotation)
            local now = os.clock()
            if now - lastSound >= Config.DRAG_SOUND_INTERVAL then
                lastSound = now
                AudioService:Emit("body_drag", spot)
            end
        end)
        dragging[plr] = { model = model :: Model, body = body, conn = conn }
        Remotes.AbilityState:FireClient(plr, "dragging", 0)
    end)
end

function AbilityService:StopDrag(plr: Player)
    pendingDrag[plr] = nil
    local d = dragging[plr]
    if not d then
        return
    end
    dragging[plr] = nil
    d.conn:Disconnect()
    d.body.draggedBy = nil
    local hum = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
    if hum and round:IsAlive(plr) then
        hum.WalkSpeed = 16
    end
    if plr.Parent == Players then
        Remotes.AbilityState:FireClient(plr, "drag_stop", 0)
    end
end

function AbilityService:Reset()
    for plr in dragging do
        self:StopDrag(plr)
    end
    pendingDrag = {}
    reviveUsed = {}
    channeling = {}
end

Players.PlayerRemoving:Connect(function(plr)
    AbilityService:StopDrag(plr)
    reviveUsed[plr] = nil
    channeling[plr] = nil
end)

return AbilityService
