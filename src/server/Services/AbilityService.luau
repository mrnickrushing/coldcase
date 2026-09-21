-- Medic revive and body dragging (Design Bible · Roles, Counterplay).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Config = require(game.ReplicatedStorage.Shared.Config)
local Reach = require(script.Parent.Reach)
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

-- Deliberately no PING_ALLOWANCE: that slack is for the reach checks a moving
-- player disputes (knife, gun pickup, coins). Examining and reviving are
-- stationary, so they use the plain range.
local function near(plr: Player, model: Instance): boolean
    return Reach.Within(plr, model, Config.EXAMINE_RANGE)
end

---------------------------------------------------------------- Revive
-- One revive per round, 3s channel, only on a body nobody has examined yet.
-- The channel breaks if the medic moves: standing still beside a body in a
-- room with a murderer is the whole cost of the ability.
--
-- Every refusal below says why. They used to return in silence, so a medic
-- pressing REVIVE on an NPC's body, or on one someone had already examined,
-- saw nothing happen at all and read the button as broken.
local function deny(plr: Player, reason: string)
    Remotes.Notify:FireClient(plr, reason)
end

function AbilityService:RequestRevive(plr: Player, model: Instance)
    -- Role and liveness are not explained: only a live medic's client ever
    -- sends this, so anything else is a forged call and is told nothing.
    if RoleService:Get(plr) ~= "medic" or channeling[plr] or not round:IsAlive(plr) then
        return
    end
    if reviveUsed[plr] then
        return deny(plr, "You have already used your revive this round.")
    end
    local body = EvidenceService:GetBody(model)
    if not body then
        return
    end
    if body.examined then
        return deny(plr, "That body has already been examined. It is too late for them.")
    end
    if body.draggedBy then
        return deny(plr, "Someone is moving that body.")
    end
    local victim = body.victimPlayer
    if
        Participant.IsBot(victim) -- an NPC has no player to bring back
        or not (victim and victim.Parent == Players and round:IsParticipant(victim))
    then
        return deny(plr, "There is nobody to bring back.")
    end
    if not near(plr, model) then
        return deny(plr, "Stand closer to the body.")
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
    if not body then
        return
    end
    if body.draggedBy then
        return deny(plr, "Someone else has hold of that body.")
    end
    if not near(plr, model) then
        return deny(plr, "Stand closer to the body.")
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
            local behind = pivot.Position - pivot.LookVector * 4
            -- Rest the body's underside on the ground behind the dragger, whether
            -- it is the generic figure or a full avatar: their pivots sit at
            -- different heights above the body, so a fixed drop is wrong for one.
            local cf, size = corpse:GetBoundingBox()
            local pivotToBottom = corpse:GetPivot().Position.Y - (cf.Position.Y - size.Y / 2)
            local rp = RaycastParams.new()
            rp.FilterType = Enum.RaycastFilterType.Exclude
            rp.FilterDescendantsInstances = { char, corpse }
            local hit = workspace:Raycast(
                Vector3.new(behind.X, pivot.Position.Y + 3, behind.Z),
                Vector3.new(0, -40, 0),
                rp
            )
            local floorY = hit and hit.Position.Y or (pivot.Position.Y - 2.5)
            local spot = Vector3.new(behind.X, floorY + pivotToBottom, behind.Z)
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
        hum.WalkSpeed = Config.WALKSPEED
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
