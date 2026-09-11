-- NPCs that fill a quiet server (Config.BOTS_ENABLED) so one person can play.
-- They are round participants like players: RoleService deals them roles,
-- CombatService kills them, EvidenceService drops their bodies and reads
-- their shirt colour for the fibre clue. They act only through the same
-- server functions a player's remotes reach, so every range check, cooldown
-- and grace period applies to them too.
local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local Config = require(game.ReplicatedStorage.Shared.Config)
local RoleService = require(script.Parent.RoleService)
local CombatService = require(script.Parent.CombatService)

local BotService = {}
local round: any = nil -- RoundService, handed over by BindRound
local bots: { any } = {}
local byCharacter: { [Instance]: any } = {}
local points: { Vector3 } = {}
local RUN_SPEED = 16 -- a player's walk speed; NPCs match it only when running

local NAMES = {
    "Otto",
    "Wren",
    "Mara",
    "Silas",
    "Iris",
    "June",
    "Felix",
    "Nell",
    "Hugo",
    "Ada",
    "Cyril",
    "Edith",
}
-- Shirts span the fibre bands, so the fibre clue still narrows an NPC down
local SHIRTS = {
    "6b3a2e",
    "2f4858",
    "5b5f3a",
    "7a2e3a",
    "3a3f58",
    "8a6a3a",
    "2e5a4a",
    "4a4a4a",
    "6a4a7a",
    "a0522d",
    "1f3b2c",
    "c8b89a",
}
local SKIN = { "f1c27d", "e0ac69", "c68642", "8d5524", "ffdbac", "a67c52" }
local TROUSERS = { "2b2b2b", "3d3a35", "1f2a38", "4a3b2c" }
-- Roblox's default R15 animations, which any experience may play
local ANIMATIONS = { walk = "rbxassetid://913402848", idle = "rbxassetid://507766666" }

-- The Player surface round code touches, so an NPC passes through unchanged
local Bot = {}
Bot.__index = Bot
function Bot:GetAttribute(key: string): any
    return self.attributes[key]
end
function Bot:SetAttribute(key: string, value: any)
    self.attributes[key] = value
end
function Bot:FindFirstChild(_name: string): Instance?
    return nil
end
function Bot:FindFirstChildOfClass(_className: string): Instance?
    return nil
end
function Bot:LoadCharacter() end
function Bot:Kick() end

local function between(bounds: { number }): number
    return bounds[1] + math.random() * (bounds[2] - bounds[1])
end

local function pick(list: { string }): string
    return list[math.random(#list)]
end

function BotService:BindRound(roundService)
    round = roundService
end

-- How many NPC seats the next round gets for this many humans
function BotService:SeatsFor(humans: number): number
    if not Config.BOTS_ENABLED or humans < 1 or humans >= Config.MIN_PLAYERS then
        return 0
    end
    return math.max(0, Config.BOT_FILL_TO - humans)
end

function BotService:FromCharacter(model: Instance): any
    return byCharacter[model]
end

---------------------------------------------------------------- Bodies
local function folder(): Folder
    local f = workspace:FindFirstChild("Bots")
    if not f then
        f = Instance.new("Folder")
        f.Name = "Bots"
        f.Parent = workspace
    end
    return f :: Folder
end

local function animate(hum: Humanoid)
    local animator = hum:FindFirstChildOfClass("Animator")
    if not animator then
        animator = Instance.new("Animator")
        animator.Parent = hum
    end
    local tracks = {}
    for key, id in ANIMATIONS do
        local animation = Instance.new("Animation")
        animation.AnimationId = id
        local ok, track = pcall(function()
            return (animator :: Animator):LoadAnimation(animation)
        end)
        if ok and track then
            track.Looped = true
            tracks[key] = track
        end
    end
    if tracks.idle then
        tracks.idle:Play()
    end
    hum.Running:Connect(function(speed)
        local walk = tracks.walk
        if not walk then
            return
        end
        if speed > 0.5 and not walk.IsPlaying then
            walk:Play(0.2)
        elseif speed <= 0.5 and walk.IsPlaying then
            walk:Stop(0.2)
        end
    end)
end

function BotService:Spawn(count: number): { any }
    local made = {}
    if count <= 0 then
        return made
    end
    local names = table.clone(NAMES)
    for i = #names, 2, -1 do
        local j = math.random(i)
        names[i], names[j] = names[j], names[i]
    end
    local lobby = workspace:FindFirstChild("Lobby")
    local spawnPart = lobby and lobby:FindFirstChild("LobbySpawn")
    local origin = if spawnPart and spawnPart:IsA("BasePart")
        then spawnPart.Position
        else Vector3.new(0, 2, -900)

    for i = 1, count do
        local description = Instance.new("HumanoidDescription")
        local shirt, skin, legs =
            Color3.fromHex(pick(SHIRTS)), Color3.fromHex(pick(SKIN)), Color3.fromHex(pick(TROUSERS))
        description.TorsoColor = shirt
        description.LeftArmColor = shirt
        description.RightArmColor = shirt
        description.HeadColor = skin
        description.LeftLegColor = legs
        description.RightLegColor = legs
        local ok, char = pcall(
            Players.CreateHumanoidModelFromDescription,
            Players,
            description,
            Enum.HumanoidRigType.R15
        )
        if not ok or not char then
            warn("[ColdCase] could not build an NPC: " .. tostring(char))
            continue
        end

        -- "(NPC)" cannot appear in a Roblox username, so names never collide
        local name = (names[i] or ("Guest" .. i)) .. " (NPC)"
        char.Name = name
        local hum = char:FindFirstChildOfClass("Humanoid") :: Humanoid
        hum.DisplayName = name
        local animateScript = char:FindFirstChild("Animate")
        if animateScript then
            animateScript:Destroy() -- a LocalScript; the server animates NPCs instead
        end
        char:SetAttribute("BotName", name)
        char:AddTag("BotCharacter")
        char:PivotTo(CFrame.new(origin + Vector3.new((i - count / 2) * 4, 4, 8)))
        char.Parent = folder()
        -- Server-owned physics: a nearby client can never fling or teleport an NPC
        for _, part in char:GetDescendants() do
            if part:IsA("BasePart") and part:CanSetNetworkOwnership() then
                part:SetNetworkOwner(nil)
            end
        end
        animate(hum)

        local bot = setmetatable({
            IsBot = true,
            Name = name,
            DisplayName = name,
            UserId = -i,
            Character = char,
            Parent = Players, -- present, as far as round code is concerned
            attributes = { Rank = 1 },
            brain = {},
        }, Bot)
        byCharacter[char] = bot
        table.insert(bots, bot)
        table.insert(made, bot)
        hum.Died:Connect(function()
            task.delay(4, function()
                if char.Parent then
                    char:Destroy()
                end
            end)
        end)
    end
    return made
end

function BotService:Clear()
    for _, bot in bots do
        if bot.Character then
            bot.Character:Destroy()
        end
    end
    bots = {}
    byCharacter = {}
end

---------------------------------------------------------------- Senses and movement
local function rootOf(bot): BasePart?
    local char = bot.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    return if root and root:IsA("BasePart") then root else nil
end

local function humanoidOf(bot): Humanoid?
    local char = bot.Character
    return char and char:FindFirstChildOfClass("Humanoid")
end

local function positionOf(p): Vector3?
    local char = p.Character
    return char and char.Parent and char:GetPivot().Position
end

local function canSee(bot, target, maxDistance: number): boolean
    local char, other = bot.Character, target.Character
    local head = char and char:FindFirstChild("Head")
    if not (head and head:IsA("BasePart") and other) then
        return false
    end
    local to = other:GetPivot().Position - head.Position
    if to.Magnitude > maxDistance then
        return false
    end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { char, other }
    return workspace:Raycast(head.Position, to, params) == nil
end

local function collectPoints()
    points = {}
    local roundFolder = workspace:FindFirstChild("Round")
    if not roundFolder then
        return
    end
    for _, d in roundFolder:GetDescendants() do
        if d:IsA("BasePart") and (d:HasTag("SpawnPoint") or d:HasTag("CoinNode")) then
            table.insert(points, d.Position)
        end
    end
end

-- Walks toward `goal` along a computed path, recomputing when the goal moves
-- or the path goes stale
local function steer(bot, goal: Vector3, speed: number)
    local brain = bot.brain
    local root, hum = rootOf(bot), humanoidOf(bot)
    if not (root and hum) then
        return
    end
    if hum.WalkSpeed ~= speed then
        hum.WalkSpeed = speed
    end
    local now = os.clock()
    if not brain.path or (brain.goal - goal).Magnitude > 8 or now - brain.pathAt > 2.5 then
        brain.goal, brain.pathAt = goal, now
        brain.pathObject = brain.pathObject
            or PathfindingService:CreatePath({
                AgentRadius = 2,
                AgentHeight = 5,
                AgentCanJump = false,
            })
        local path = brain.pathObject
        local ok = pcall(function()
            path:ComputeAsync(root.Position, goal)
        end)
        if ok and path.Status == Enum.PathStatus.Success then
            brain.path, brain.step = path:GetWaypoints(), 2
        else
            brain.path, brain.step = { { Position = goal } }, 1
        end
    end
    local waypoint = brain.path[brain.step]
    while waypoint do
        local flat = Vector3.new(waypoint.Position.X, root.Position.Y, waypoint.Position.Z)
        if (flat - root.Position).Magnitude >= 3 then
            break
        end
        brain.step += 1
        waypoint = brain.path[brain.step]
    end
    hum:MoveTo(if waypoint then waypoint.Position else goal)
end

local function stop(bot)
    local root, hum = rootOf(bot), humanoidOf(bot)
    if root and hum then
        hum:MoveTo(root.Position)
    end
end

local function wander(bot, now: number)
    local brain = bot.brain
    local root = rootOf(bot)
    if not root or #points == 0 then
        return
    end
    if now < (brain.lingerUntil or 0) then
        stop(bot)
        return
    end
    local target = brain.wanderTo
    if
        not target
        or (Vector3.new(target.X, root.Position.Y, target.Z) - root.Position).Magnitude < 5
        or now > (brain.wanderUntil or 0)
    then
        if target then
            brain.wanderTo = nil
            brain.lingerUntil = now + 1 + math.random() * 3
            stop(bot)
            return
        end
        brain.wanderTo = points[math.random(#points)]
        brain.wanderUntil = now + 20
    end
    local speed = if now < (brain.fleeUntil or 0) then RUN_SPEED else Config.BOT_STROLL_SPEED
    steer(bot, brain.wanderTo, speed)
end

-- Heads for whichever of a few random spots is farthest from the danger
local function flee(bot, from: Vector3)
    if #points == 0 then
        return
    end
    local best, bestDistance = nil, -1
    for _ = 1, 6 do
        local p = points[math.random(#points)]
        local d = (p - from).Magnitude
        if d > bestDistance then
            best, bestDistance = p, d
        end
    end
    local now = os.clock()
    bot.brain.wanderTo = best
    bot.brain.wanderUntil = now + 12
    bot.brain.fleeUntil = now + 6
    bot.brain.lingerUntil = 0
end

---------------------------------------------------------------- Brains
-- Murderer: blends in, then stalks whoever is most alone
local function hunt(bot, now: number)
    local brain = bot.brain
    brain.nextHunt = brain.nextHunt or now + between(Config.BOT_FIRST_HUNT)
    if now < brain.nextHunt then
        wander(bot, now)
        return
    end
    local root = rootOf(bot)
    if not root then
        return
    end
    local target = brain.target
    if target and now - (brain.targetSince or now) > Config.BOT_CHASE_GIVE_UP then
        target = nil -- this one keeps getting away; look for someone easier
    end
    if not (target and round:IsAlive(target)) then
        target = nil
        local bestScore = math.huge
        local living = round:AliveParticipants()
        for _, p in living do
            local pos = positionOf(p)
            if p ~= bot and pos and RoleService:Get(p) ~= "murderer" then
                local crowd = 0
                for _, q in living do
                    local qpos = positionOf(q)
                    if q ~= p and q ~= bot and qpos and (qpos - pos).Magnitude < 25 then
                        crowd += 1
                    end
                end
                local score = (pos - root.Position).Magnitude + crowd * 60 + math.random() * 30
                if p == brain.target then
                    score += 80 -- just gave up on them
                end
                if score < bestScore then
                    target, bestScore = p, score
                end
            end
        end
        brain.target = target
        brain.targetSince = now
    end
    local pos = target and positionOf(target)
    if not pos then
        wander(bot, now)
        return
    end
    local distance = (pos - root.Position).Magnitude
    if distance <= Config.KNIFE_RANGE - 2 then
        CombatService:RequestStab(bot, target)
        if not round:IsAlive(target) then
            brain.target = nil
            brain.nextHunt = now + between(Config.BOT_HUNT_PAUSE)
            flee(bot, pos)
        end
    else
        -- Head for where they are going, not where they were
        local targetRoot = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
        local lead = if targetRoot and targetRoot:IsA("BasePart")
            then targetRoot.AssemblyLinearVelocity * math.min(distance / RUN_SPEED, 1.2)
            else Vector3.zero
        steer(bot, pos + Vector3.new(lead.X, 0, lead.Z), RUN_SPEED)
    end
end

-- Sheriff or hero: only ever fires on a killer it saw, or the murderer Last
-- Call outlines for everyone
local function patrol(bot, now: number)
    local brain = bot.brain
    if
        round:TimeLeft() <= Config.LAST_CALL_AT
        and not (brain.suspect and round:IsAlive(brain.suspect))
    then
        for _, p in round:AliveParticipants() do
            if RoleService:Get(p) == "murderer" then
                brain.suspect = p
                brain.fireAt = now + between(Config.BOT_REACTION)
                break
            end
        end
    end
    local suspect = brain.suspect
    local pos = suspect and round:IsAlive(suspect) and positionOf(suspect)
    local root = rootOf(bot)
    if not (pos and root) then
        brain.suspect = nil
        wander(bot, now)
        return
    end
    local distance = (pos - root.Position).Magnitude
    if distance <= Config.GUN_RANGE * 0.3 and canSee(bot, suspect, Config.GUN_RANGE * 0.3) then
        stop(bot)
        if now >= (brain.fireAt or 0) then
            local spread = distance / 45
            local aim = pos
                + Vector3.new(
                    (math.random() - 0.5) * 2 * spread,
                    1.5 + (math.random() - 0.5) * spread,
                    (math.random() - 0.5) * 2 * spread
                )
            CombatService:RequestShoot(bot, aim)
            brain.fireAt = now + Config.GUN_COOLDOWN + between(Config.BOT_REACTION) * 0.5
        end
    else
        steer(bot, pos, RUN_SPEED)
    end
end

local function think(bot)
    local now = os.clock()
    local role = RoleService:Get(bot)
    if role == "murderer" then
        hunt(bot, now)
    elseif role == "sheriff" or role == "hero" then
        patrol(bot, now)
    else
        wander(bot, now)
    end
end

function BotService:StartRound()
    collectPoints()
    for _, bot in bots do
        bot.brain = {}
        task.spawn(function()
            while round:GetState() == "ACTIVE" and round:IsAlive(bot) do
                local ok, err = pcall(think, bot)
                if not ok then
                    warn("[ColdCase] NPC " .. bot.Name .. ": " .. tostring(err))
                    task.wait(1)
                end
                task.wait(0.25)
            end
            local hum = humanoidOf(bot)
            if hum and hum.Health > 0 then
                stop(bot)
            end
        end)
    end
end

-- A kill someone saw: NPC sheriffs mark the killer, everyone else runs
function BotService:OnDeath(victim, killer, method: string, position: Vector3)
    if not killer or killer == victim then
        return
    end
    local now = os.clock()
    for _, bot in bots do
        if bot == killer or bot == victim or not round:IsAlive(bot) then
            continue
        end
        local root = rootOf(bot)
        if
            not root
            or (root.Position - position).Magnitude > Config.BOT_SIGHT
            or not canSee(bot, killer, Config.BOT_SIGHT)
        then
            continue
        end
        local role = RoleService:Get(bot)
        if (role == "sheriff" or role == "hero") and (method == "knife" or method == "throw") then
            bot.brain.suspect = killer
            bot.brain.fireAt = now + between(Config.BOT_REACTION)
        elseif role ~= "murderer" then
            flee(bot, position)
        end
    end
end

return BotService
