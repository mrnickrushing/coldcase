--!strict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Config = require(game.ReplicatedStorage.Shared.Config)
local RoleService = require(script.Parent.RoleService)
local AudioService = require(script.Parent.AudioService)
local EvidenceService = require(script.Parent.EvidenceService)
local CosmeticService = require(script.Parent.CosmeticService)
local CombatFx = require(game.ReplicatedStorage.Shared.CombatFx)
local Participant = require(script.Parent.Participant)
local Remotes = game.ReplicatedStorage.Remotes

local CombatService = {}
local lastAction = {} -- [Player] = { [action] = os.clock() }
local roundStart = 0
local droppedGun: BasePart? = nil
local round: any = nil -- RoundService, handed over by BindRound

function CombatService:BindRound(roundService)
    round = roundService
end

function CombatService:MarkRoundStart()
    roundStart = os.clock()
    lastAction = {}
    droppedGun = nil
end

-- The gun a fallen sheriff leaves behind for someone to pick up and become the
-- hero. Uses the real revolver mesh from Cosmetics, scaled up a little and given
-- a soft in-sight outline so it is unmistakably a gun and still easy to spot,
-- with a plain gold part as the fallback if the cosmetic is missing. Stays a
-- single BasePart, so RequestPickup's position and destroy logic is unchanged.
local function makeDroppedGun(pos: Vector3): BasePart
    local cos = game:GetService("ServerStorage"):FindFirstChild("Cosmetics")
    local template = cos and cos:FindFirstChild("gun")
    local handle = template and template:FindFirstChild("Handle")
    local gun: BasePart
    if handle and handle:IsA("BasePart") then
        gun = handle:Clone()
        for _, d in gun:GetChildren() do
            if not d:IsA("DataModelMesh") then
                d:Destroy() -- shed any emitters or outlines carried by the cosmetic
            end
        end
        gun.Size = gun.Size * 1.5
    else
        gun = Instance.new("Part")
        gun.Size = Vector3.new(2, 0.6, 1)
        gun.Color = Color3.fromHex("f2a63b")
        gun.Material = Enum.Material.SmoothPlastic
    end
    gun.Name = "DroppedPistol"
    gun.Anchored = true
    gun.CanCollide = false
    gun.CanQuery = false
    gun.Massless = true
    gun.CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(20))
    gun:AddTag("DroppedPistol")
    local glow = Instance.new("Highlight")
    glow.FillTransparency = 1
    glow.OutlineColor = Color3.fromHex("ffd98a")
    glow.OutlineTransparency = 0.15
    glow.DepthMode = Enum.HighlightDepthMode.Occluded
    glow.Parent = gun
    return gun
end

local function inGrace(): boolean
    return os.clock() - roundStart < Config.WEAPON_GRACE
end

-- Server-side cooldown per player per action. The client cooldown is cosmetic.
local function ready(plr: Player, action: string, cooldown: number): boolean
    local t = os.clock()
    local mine = lastAction[plr]
    if not mine then
        mine = {}
        lastAction[plr] = mine
    end
    if t - (mine[action] or 0) < cooldown then
        return false
    end
    mine[action] = t
    return true
end

-- The character of a player who is alive in the round, or nil
local function liveCharacter(plr: Player): Model?
    if not round:IsAlive(plr) then
        return nil
    end
    return plr.Character
end

-- The player or NPC whose character this part belongs to
local function playerFromPart(part: Instance): any
    local model = part:FindFirstAncestorOfClass("Model")
    while model do
        local plr = Players:GetPlayerFromCharacter(model)
        if plr then
            return plr
        end
        local bot = round and round:BotFromCharacter(model)
        if bot then
            return bot
        end
        model = model:FindFirstAncestorOfClass("Model")
    end
    return nil
end

local function rayParams(char: Model): RaycastParams
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local ignore: { Instance } = { char }
    local lobby = workspace:FindFirstChild("Lobby")
    if lobby then
        table.insert(ignore, lobby)
    end
    params.FilterDescendantsInstances = ignore
    return params
end

-- The client asks to stab. The server decides whether it happened.
function CombatService:RequestStab(plr: Player, target: Player)
    if target == plr or inGrace() or RoleService:Get(plr) ~= "murderer" then
        return
    end
    local myChar, theirChar = liveCharacter(plr), liveCharacter(target)
    if not (myChar and theirChar) then
        return
    end
    if not ready(plr, "knife", Config.KNIFE_COOLDOWN) then
        return
    end
    CosmeticService:DrawWeapon(plr, "knife", Config.WEAPON_DRAW_TIME)

    local a = myChar:GetPivot().Position
    AudioService:Emit("knife_swing", a)
    -- Real positions only, with a small allowance for ping
    local b = theirChar:GetPivot().Position
    if (a - b).Magnitude > Config.KNIFE_RANGE + Config.PING_ALLOWANCE then
        return
    end
    self:Eliminate(target, plr, "knife")
end

function CombatService:RequestThrow(plr: Player, aimPoint: Vector3)
    local char = liveCharacter(plr)
    if not char or inGrace() or RoleService:Get(plr) ~= "murderer" then
        return
    end
    local origin = char:GetPivot().Position + Vector3.new(0, 1.5, 0)
    local toAim = aimPoint - origin
    if toAim.Magnitude < 1 then
        return
    end
    if not ready(plr, "throw", Config.THROW_COOLDOWN) then
        return
    end
    CosmeticService:DrawWeapon(plr, "knife", Config.WEAPON_DRAW_TIME)

    local dir = toAim.Unit
    AudioService:Emit("knife_throw", origin)
    local params = rayParams(char)

    task.spawn(function()
        local pos, flown = origin, 0
        while flown < Config.THROW_MAX_FLIGHT do
            local dt = RunService.Heartbeat:Wait()
            if round:GetState() ~= "ACTIVE" then
                return
            end
            flown += dt
            local hit = workspace:Raycast(pos, dir * Config.THROW_SPEED * dt, params)
            if hit then
                local victim = playerFromPart(hit.Instance)
                if victim and victim ~= plr and round:IsAlive(victim) then
                    self:Eliminate(victim, plr, "throw")
                end
                return
            end
            pos += dir * Config.THROW_SPEED * dt
        end
    end)
end

function CombatService:RequestShoot(plr: Player, aimPoint: Vector3)
    local role = RoleService:Get(plr)
    local char = liveCharacter(plr)
    if not char or inGrace() or (role ~= "sheriff" and role ~= "hero") then
        return
    end
    if not ready(plr, "gun", Config.GUN_COOLDOWN) then
        return
    end
    CosmeticService:DrawWeapon(plr, "gun", Config.WEAPON_DRAW_TIME)

    -- Never trust a client origin: fire from the real character
    local head = char:FindFirstChild("Head")
    local origin = if head and head:IsA("BasePart") then head.Position else char:GetPivot().Position
    local toAim = aimPoint - origin
    if toAim.Magnitude < 1 then
        return
    end
    AudioService:Emit("gun_fire", origin)
    CombatFx.Muzzle(origin, toAim.Unit)

    local hit = workspace:Raycast(origin, toAim.Unit * Config.GUN_RANGE, rayParams(char))
    local victim = hit and playerFromPart(hit.Instance)
    if not victim or not round:IsAlive(victim) then
        return
    end

    self:Eliminate(victim, plr, "gun")

    -- Misfire penalty: without it, sheriffs spray on sight and deduction never happens.
    if Config.SHERIFF_MISFIRE_KILLS_SELF and RoleService:Get(victim) ~= "murderer" then
        AudioService:Play2D(plr, "misfire_death")
        self:Eliminate(plr, plr, "misfire")
    end
end

function CombatService:RequestPickup(plr: Player)
    local gun = droppedGun
    local char = liveCharacter(plr)
    if not (gun and gun.Parent and char) then
        return
    end
    local reach = Config.GUN_PICKUP_RANGE + Config.PING_ALLOWANCE
    if (char:GetPivot().Position - gun.Position).Magnitude > reach then
        return
    end
    if RoleService:MakeHero(plr) then
        AudioService:Emit("gun_pickup", gun.Position)
        CombatFx.Hero(char:GetPivot().Position)
        gun:Destroy()
        droppedGun = nil
    end
end

function CombatService:Eliminate(victim: Player, killer: Player, method: string)
    local char = liveCharacter(victim)
    if not char then
        return
    end
    local pos = char:GetPivot().Position
    CombatFx.Impact(pos)

    local role = RoleService:Get(victim)
    local roundFolder = workspace:FindFirstChild("Round")
    if roundFolder and (role == "sheriff" or role == "hero") and not droppedGun then
        local gun = makeDroppedGun(pos)
        gun.Parent = roundFolder
        droppedGun = gun
    end

    if method == "knife" or method == "throw" then
        AudioService:Emit("knife_hit", pos)
    end
    if method ~= "misfire" then
        EvidenceService:DropBody(victim, killer)
    end

    -- Mark dead before the humanoid dies so the Died listener is a no-op
    round:MarkDead(victim, killer, method)
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.Health = 0
    end

    -- Tell the killer they landed it (hitmarker, kill line, camera kick).
    -- Never on a misfire suicide, and never to an NPC with no client.
    if killer and killer ~= victim and not Participant.IsBot(killer) then
        Remotes.KillConfirm:FireClient(killer, role)
    end
end

Players.PlayerRemoving:Connect(function(plr)
    lastAction[plr] = nil
end)

return CombatService
