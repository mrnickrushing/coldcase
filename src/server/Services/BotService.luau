-- NPCs that fill a quiet server (Config.BOTS_ENABLED) so one person can play.
-- They are round participants like players: RoleService deals them roles,
-- CombatService kills them, EvidenceService drops their bodies and reads
-- their shirt colour for the fibre clue. They act only through the same
-- server functions a player's remotes reach, so every range check, cooldown
-- and grace period applies to them too.
local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local Config = require(game.ReplicatedStorage.Shared.Config)
local MapPlan = require(game.ReplicatedStorage.Shared.MapPlan)
local FibreBands = require(game.ReplicatedStorage.Shared.FibreBands)
local RoleService = require(script.Parent.RoleService)
local CombatService = require(script.Parent.CombatService)

local BotService = {}
local round: any = nil -- RoundService, handed over by BindRound
local bots: { any } = {}
local byCharacter: { [Instance]: any } = {}
local points: { Vector3 } = {}
local plan, planAnalysis = nil, nil -- the map being played, for room-to-room routing
local RUN_SPEED = Config.WALKSPEED -- a player's walk speed; NPCs match it only when running

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

local function shuffled(list: { string }): { string }
    local out = table.clone(list)
    for i = #out, 2, -1 do
        local j = math.random(i)
        out[i], out[j] = out[j], out[i]
    end
    return out
end

-- The fibre clue names the colour band of the killer's shirt, so a round where
-- three NPCs wear the same band narrows almost nothing. Shirts are dealt one
-- band at a time, and never handed out twice.
local function shirtDeck(): { string }
    local byBand: { [string]: { string } } = {}
    local order = {}
    for _, hex in shuffled(SHIRTS) do
        local band = FibreBands.Describe(Color3.fromHex(hex):ToHSV())
        if not byBand[band] then
            byBand[band] = {}
            table.insert(order, band)
        end
        table.insert(byBand[band], hex)
    end
    local deck = {}
    local more = true
    while more do
        more = false
        for _, band in order do
            local hex = table.remove(byBand[band])
            if hex then
                table.insert(deck, hex)
                more = more or #byBand[band] > 0
            end
        end
    end
    return deck
end

function BotService:BindRound(roundService)
    round = roundService
end

---------------------------------------------------------------- The rig
-- One plain R15 rig, built once and cloned for every NPC. Building it loads
-- assets and can fail on a busy live server, so it retries, and as a last
-- resort copies a player's body stripped of everything that makes it theirs.
local rigTemplate: Model? = nil

local function copyOfPlayer(): Model?
    for _, plr in Players:GetPlayers() do
        local char = plr.Character
        if char and char:FindFirstChild("HumanoidRootPart") then
            local was = char.Archivable
            char.Archivable = true
            local copy = char:Clone()
            char.Archivable = was
            if copy then
                for _, d in copy:GetDescendants() do
                    if
                        d:IsA("LuaSourceContainer")
                        or d:IsA("Accessory")
                        or d:IsA("Clothing")
                        or d:IsA("ShirtGraphic")
                        or d:IsA("Decal")
                        or d:IsA("Tool")
                        or d:IsA("ForceField")
                    then
                        d:Destroy()
                    end
                end
                return copy
            end
        end
    end
    return nil
end

local function rig(): Model?
    if rigTemplate then
        return rigTemplate
    end
    for attempt = 1, 3 do
        local ok, model = pcall(
            Players.CreateHumanoidModelFromDescription,
            Players,
            Instance.new("HumanoidDescription"),
            Enum.HumanoidRigType.R15
        )
        if ok and model then
            rigTemplate = model
            break
        end
        warn(("[ColdCase] NPC rig, attempt %d: %s"):format(attempt, tostring(model)))
        task.wait(attempt)
    end
    rigTemplate = rigTemplate or copyOfPlayer()
    local template = rigTemplate
    if template then
        local animateScript = template:FindFirstChild("Animate")
        if animateScript then
            animateScript:Destroy() -- a LocalScript; the server animates NPCs instead
        end
    end
    return template
end

-- Bootstrap warms the rig on server start, so the first round never waits on it
function BotService:Prepare()
    task.spawn(rig)
end

local function colour(char: Model, shirt: Color3, skin: Color3, legs: Color3)
    local body = char:FindFirstChildOfClass("BodyColors")
    if body then
        body.HeadColor3 = skin
        body.TorsoColor3 = shirt
        body.LeftArmColor3 = shirt
        body.RightArmColor3 = shirt
        body.LeftLegColor3 = legs
        body.RightLegColor3 = legs
    end
    for _, part in char:GetDescendants() do
        if part:IsA("BasePart") then
            local name = part.Name
            if name == "Head" then
                part.Color = skin
            elseif
                string.find(name, "Torso")
                or string.find(name, "Arm")
                or string.find(name, "Hand")
            then
                part.Color = shirt
            elseif string.find(name, "Leg") or string.find(name, "Foot") then
                part.Color = legs
            end
        end
    end
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
    local names = shuffled(NAMES)
    local shirts = shirtDeck()
    local lobby = workspace:FindFirstChild("Lobby")
    local spawnPart = lobby and lobby:FindFirstChild("LobbySpawn")
    local origin = if spawnPart and spawnPart:IsA("BasePart")
        then spawnPart.Position
        else Vector3.new(0, 2, -900)

    local template = rig()
    if not template then
        warn("[ColdCase] no NPC rig could be built")
        return made
    end

    for i = 1, count do
        local char = template:Clone()
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum then
            continue
        end
        colour(
            char,
            Color3.fromHex(shirts[i] or pick(SHIRTS)),
            Color3.fromHex(pick(SKIN)),
            Color3.fromHex(pick(TROUSERS))
        )

        -- "(NPC)" cannot appear in a Roblox username, so names never collide
        local name = (names[i] or ("Guest" .. i)) .. " (NPC)"
        char.Name = name
        hum.DisplayName = name
        hum.Health = hum.MaxHealth
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

-- NPCs cross a building a few rooms at a time: the plan says which cells lead
-- to the goal, and the NPC heads for one a short way along that route. Short
-- legs keep each path request cheap and reliable, and they send an NPC through
-- the doorways and up the stairs the plan knows about rather than guessing.
local function leg(root: BasePart, goal: Vector3): Vector3
    if not (plan and planAnalysis) then
        return goal
    end
    local here = root.Position
    local f1, x1, z1 = MapPlan.CellAt(plan, here.X, here.Y, here.Z)
    local f2, x2, z2 = MapPlan.CellAt(plan, goal.X, goal.Y, goal.Z)
    if f1 == f2 and math.abs(x1 - x2) <= 2 and math.abs(z1 - z2) <= 2 then
        return goal -- close enough to walk straight at it
    end
    local route = MapPlan.Route(
        plan,
        planAnalysis,
        { f = f1, x = x1, z = z1 },
        { f = f2, x = x2, z = z2 }
    )
    if not route or #route == 0 then
        return goal
    end
    local step = route[math.min(#route, 3)]
    local x, y, z = MapPlan.Position(plan, step.f, step.x, step.z)
    return Vector3.new(x, y + 3, z)
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
    local here = leg(root, goal)
    if not brain.path or (brain.goal - here).Magnitude > 8 or now - brain.pathAt > 2.5 then
        brain.goal, brain.pathAt = here, now
        brain.pathObject = brain.pathObject
            or PathfindingService:CreatePath({
                AgentRadius = 2,
                AgentHeight = 5,
                AgentCanJump = false,
            })
        local path = brain.pathObject
        local ok = pcall(function()
            path:ComputeAsync(root.Position, here)
        end)
        if ok and path.Status == Enum.PathStatus.Success then
            brain.path, brain.step = path:GetWaypoints(), 2
            brain.lost = nil
        else
            -- Walking straight at a goal on another floor gets nowhere
            brain.path, brain.step = { { Position = here } }, 1
            brain.lost = goal
        end
    end
    local waypoint = brain.path[brain.step]
    while waypoint do
        local flat = Vector3.new(waypoint.Position.X, root.Position.Y, waypoint.Position.Z)
        if
            (flat - root.Position).Magnitude >= 3
            or math.abs(waypoint.Position.Y - root.Position.Y) > 6
        then
            break
        end
        brain.step += 1
        waypoint = brain.path[brain.step]
    end
    hum:MoveTo(if waypoint then waypoint.Position else here)
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
    -- Arrived means the same floor too: a spot straight overhead is not reached
    local arrived = target ~= nil
        and (Vector3.new(target.X, root.Position.Y, target.Z) - root.Position).Magnitude < 5
        and math.abs(target.Y - root.Position.Y) < 6
    if not target or arrived or brain.lost == target or now > (brain.wanderUntil or 0) then
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
    plan = round and MapPlan.MAPS[round:MapName()] or nil
    planAnalysis = plan and MapPlan.Analyse(plan) or nil
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
