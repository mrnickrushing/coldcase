-- The heartbeat. Every transition is server-authoritative.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Shuffle = require(ReplicatedStorage.Shared.Shuffle)
local Modes = require(ReplicatedStorage.Shared.Modes)
local Remotes = ReplicatedStorage.Remotes
local RoleService = require(script.Parent.RoleService)
local EventService = require(script.Parent.EventService)
local EconomyService = require(script.Parent.EconomyService)
local EvidenceService = require(script.Parent.EvidenceService)
local CombatService = require(script.Parent.CombatService)
local CoinService = require(script.Parent.CoinService)
local AbilityService = require(script.Parent.AbilityService)
local DataService = require(script.Parent.DataService)
local Analytics = require(script.Parent.Analytics)
local OnboardingService = require(script.Parent.OnboardingService)
local SpectatorService = require(script.Parent.SpectatorService)
local BotService = require(script.Parent.BotService)
local Participant = require(script.Parent.Participant)
local LightingMood = require(script.Parent.LightingMood)
local SnitchService = require(script.Parent.SnitchService)
local WhodunnitService = require(script.Parent.WhodunnitService)
local Lobby = require(ReplicatedStorage.Shared.Lobby)

local RoundService = {}
local state, stateEnds = "INTERMISSION", math.huge -- no deadline until the lobby arms
local participants: { Player } = {} -- Players and NPCs (see Participant)
local pendingBots = 0
local votes: { [Player]: string } = {}
local alive: { [Player]: boolean } = {}
local diedConnections: { RBXScriptConnection } = {}
local eventFired, snitchRevealed, lastCallFired = false, false, false
local roundsPlayed = 0
local currentMode = "classic"

-- Classic by default; a special mode every MODE_ROTATE_EVERY rounds, cycling
-- through Modes.ROTATION. Studio can force one with ServerStorage.ForceMode.
local function pickMode(): string
    local forced = RunService:IsStudio() and ServerStorage:GetAttribute("ForceMode")
    if type(forced) == "string" and Modes.DEFS[forced] then
        return forced
    end
    roundsPlayed += 1
    if #Modes.ROTATION > 0 and roundsPlayed % Config.MODE_ROTATE_EVERY == 0 then
        local slot = (roundsPlayed // Config.MODE_ROTATE_EVERY - 1) % #Modes.ROTATION + 1
        return Modes.ROTATION[slot]
    end
    return "classic"
end
local currentMapName, mapIsIndoor = "none", true
local activeStart, roundLength = 0, Config.ROUND_LENGTH
-- Public only after the round resolves: { at, killer?, victim, method }
local timeline: { { at: number, killer: string?, victim: string, method: string, pos: Vector3? } } =
    {}
RoundService.clueCounts = {} :: { [Player]: number }

local function setState(new: string, duration: number)
    state, stateEnds = new, os.clock() + duration
    -- Attributes let late joiners and the HUD timer sync without os.clock drift.
    -- RoundEnds goes first: every client handler for the RoundState change reads
    -- RoundEnds inside that handler, so setting it second handed them the
    -- previous state's deadline. Usually the stale value had only just expired
    -- and nobody noticed; after LOADING, which overruns by a couple of seconds
    -- while the map clones, it was nearly four seconds out of date.
    ReplicatedStorage:SetAttribute("RoundEnds", workspace:GetServerTimeNow() + duration)
    ReplicatedStorage:SetAttribute("RoundState", new)
    for _, plr in Players:GetPlayers() do
        DataService:SetScreen(plr, (new == "ACTIVE" and not alive[plr]) and "SPECTATING" or new)
    end
end

-- The lobby with no countdown: nobody has asked for a round yet. RoundEnds
-- is 0, which the lobby reads as "choose how to play" rather than a timer.
local function idleLobby()
    state, stateEnds = "INTERMISSION", math.huge
    ReplicatedStorage:SetAttribute("RoundEnds", 0)
    ReplicatedStorage:SetAttribute("RoundState", "INTERMISSION")
    for _, plr in Players:GetPlayers() do
        DataService:SetScreen(plr, "INTERMISSION")
    end
end

local function aliveList(): { Player }
    local out = {}
    for plr in alive do
        table.insert(out, plr)
    end
    return out
end

-- Sorted so every spectator cycles through the same order
local function aliveNames(): { string }
    local out = {}
    for plr in alive do
        table.insert(out, plr.Name)
    end
    table.sort(out)
    return out
end

local function broadcastAlive()
    Remotes.AliveChanged:FireAllClients(#aliveList())
end

local function broadcastTally()
    local tally = {}
    for _, m in votes do
        tally[m] = (tally[m] or 0) + 1
    end
    Remotes.VoteTally:FireAllClients(tally)
end

local function minPlayers(): number
    -- Studio only: set ServerStorage.MinPlayers = 1 to test solo
    local override = RunService:IsStudio() and ServerStorage:GetAttribute("MinPlayers")
    return type(override) == "number" and override or Config.MIN_PLAYERS
end

local function lengthFor(count: number): number
    if count < Config.ROUND_SMALL_UNDER then
        return Config.ROUND_LENGTH_SMALL
    elseif count >= Config.ROUND_LARGE_AT then
        return Config.ROUND_LENGTH_LARGE
    end
    return Config.ROUND_LENGTH
end

function RoundService:GetState(): string
    return state
end

-- Who would play if the countdown ended now: those who pressed PLAY NOW,
-- and only them. Everyone else waits in the lobby for real players
-- (Lobby.Plan has the reasoning).
--
-- Counted by loaded profile, not by character. A player who resets has no
-- Character for a moment, and counting them out for that moment idled the
-- lobby and restarted the whole countdown when they were back - in a full
-- lobby, repeated resets kept a round from ever starting. Whoever still has
-- no character once the round loads is dropped there, by the `present`
-- filter in Advance.
local function lobbyPlan(): (Lobby.Plan, { Player }, { Player })
    local humans, playing = {}, {}
    for _, plr in Players:GetPlayers() do
        if DataService:Get(plr) then
            table.insert(humans, plr)
            if plr:GetAttribute("WaitForPlayers") == false then
                table.insert(playing, plr)
            end
        end
    end
    local plan =
        Lobby.Plan(#humans, #playing, minPlayers(), Config.BOT_FILL_TO, Config.BOTS_ENABLED)
    return plan, humans, playing
end

-- The countdown runs only while a round could start: someone has pressed
-- PLAY NOW, or enough real players are in. Until then the lobby idles with
-- no deadline, so a fresh join meets the choice before any timer. It starts
-- the moment the plan allows and stops the moment it no longer does.
local lobbyArmed = false
function RoundService:ArmLobby()
    local plan = lobbyPlan()
    if plan.start and not lobbyArmed then
        lobbyArmed = true
        setState("INTERMISSION", Config.INTERMISSION)
    elseif not plan.start and lobbyArmed then
        lobbyArmed = false
        idleLobby()
    end
end

-- Back to the lobby between rounds: idle, then arm at once if the players
-- who chose PLAY NOW are still here, so a chosen game keeps going by itself
function RoundService:EnterLobby()
    lobbyArmed = false
    idleLobby()
    self:ArmLobby()
end

function RoundService:TimeLeft(): number
    return math.max(0, stateEnds - os.clock())
end

-- True only for a participant who is still alive in an ACTIVE round
function RoundService:IsAlive(plr: Player): boolean
    return state == "ACTIVE" and alive[plr] == true and plr.Character ~= nil
end

function RoundService:IsParticipant(plr: Player): boolean
    return table.find(participants, plr) ~= nil
end

function RoundService:MapName(): string
    return currentMapName
end

function RoundService:AliveNames(): { string }
    return aliveNames()
end

function RoundService:AliveParticipants(): { any }
    return aliveList()
end

function RoundService:BotFromCharacter(model: Instance): any
    return BotService:FromCharacter(model)
end

-- Returns whether the vote was accepted, so the caller can tell a real vote
-- from a rejected one without re-checking the map name itself.
function RoundService:CastVote(plr: Player, mapName: string): boolean
    if state ~= "INTERMISSION" or not table.find(Config.MAPS, mapName) then
        return false
    end
    votes[plr] = mapName
    broadcastTally()
    return true
end

local function winningMap(): string
    local tally = {}
    for _, m in votes do
        tally[m] = (tally[m] or 0) + 1
    end
    local best, bestN = nil, 0
    for m, n in tally do
        if n > bestN then
            best, bestN = m, n
        end
    end
    return best or Config.MAPS[math.random(#Config.MAPS)]
end

-- Built as LOADING begins rather than as it ends. Cloning a map floods
-- replication, and a client that receives the burst late receives the state
-- change behind it late too: measured, the server ran a full 4s REVEAL while
-- clients saw 2.5s, so a role card meant to be readable for four seconds was
-- on screen for two and a half. Building here gives the LOADING window
-- something to do - absorbing that burst is the reason it exists.
function RoundService:BuildVotedMap()
    local old = workspace:FindFirstChild("Round")
    if old then
        old:Destroy()
    end
    local folder = Instance.new("Folder")
    folder.Name = "Round"
    folder.Parent = workspace

    currentMapName = winningMap()
    mapIsIndoor = currentMapName ~= "RustedPier"
    -- The loading screen names the scene; set before the state flips to
    -- LOADING so no client shows the screen before it knows the name
    ReplicatedStorage:SetAttribute("RoundMap", currentMapName)
    local template = ServerStorage.Maps:FindFirstChild(currentMapName)
    if template then
        template:Clone().Parent = folder
    else
        warn("[ColdCase] missing map " .. currentMapName)
    end
    LightingMood.Apply(currentMapName)
    votes = {}
    broadcastTally()
end

-- Kept separate from building because it needs the final participant list:
-- NPCs are spawned and absent players dropped after the map is already up.
function RoundService:PlaceParticipants()
    local folder = workspace:FindFirstChild("Round")
    if not folder then
        return
    end

    local spawns = {}
    for _, part in folder:GetDescendants() do
        if part:IsA("BasePart") and part:HasTag("SpawnPoint") then
            table.insert(spawns, part)
        end
    end
    Shuffle.Shuffle(spawns)

    -- Spawn with a minimum pairwise separation, or someone dies before they
    -- have moved. When no spawn clears the minimum, take the one farthest
    -- from everyone already placed rather than leaving a player in the lobby.
    -- More participants than pads would otherwise leave people standing in the
    -- lobby while the round runs without them: at a full server that stranded
    -- five of twelve, the human among them. Refill from the same pads instead.
    local allSpawns = table.clone(spawns)
    local used = {}
    for _, plr in participants do
        local char = plr.Character
        if not char then
            continue
        end
        if #spawns == 0 then
            spawns = table.clone(allSpawns)
            used = {}
        end
        local bestIndex, bestGap = 1, -1
        for i, s in spawns do
            local gap = math.huge
            for _, u in used do
                gap = math.min(gap, (s.Position - u).Magnitude)
            end
            if gap >= Config.SPAWN_MIN_SEP then
                bestIndex = i
                break
            elseif gap > bestGap then
                bestIndex, bestGap = i, gap
            end
        end
        local s = table.remove(spawns, bestIndex)
        char:PivotTo(s.CFrame + Vector3.new(0, 3, 0))
        table.insert(used, s.Position)
    end
end

function RoundService:SetMovementLocked(locked: boolean)
    for _, plr in participants do
        local hum = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.WalkSpeed = locked and 0 or Config.WALKSPEED
            hum.JumpHeight = locked and 0 or 7.2
            hum.JumpPower = locked and 0 or 50
        end
    end
end

local function watchDeath(self, plr: Player)
    local hum = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
    if hum then
        table.insert(
            diedConnections,
            hum.Died:Connect(function()
                self:MarkDead(plr, nil, "reset")
            end)
        )
    end
end

-- Every death funnels through here, whatever caused it
function RoundService:MarkDead(plr: Player, killer: Player?, method: string)
    if not alive[plr] then
        return
    end
    alive[plr] = nil
    local killerRole = method
    if method == "misfire" then
        killerRole = "self"
    elseif killer then
        killerRole = RoleService:Get(killer) or method
    end
    local pos = plr.Character and plr.Character:GetPivot().Position or Vector3.zero
    local elapsed = os.clock() - activeStart
    if not Participant.IsBot(plr) then
        Analytics.PlayerDeath(
            plr,
            RoleService:Get(plr) or "unknown",
            killerRole,
            elapsed,
            currentMapName,
            pos
        )
    end
    if killer then
        table.insert(
            timeline,
            { at = elapsed, killer = killer.Name, victim = plr.Name, method = method, pos = pos }
        )
    end
    AbilityService:StopDrag(plr)
    DataService:SetScreen(plr, "SPECTATING")
    broadcastAlive()
    if state == "ACTIVE" then
        local names = aliveNames()
        SpectatorService:Broadcast(names)
        if method ~= "left" then
            SpectatorService:Enter(plr, names)
        end
        BotService:OnDeath(plr, killer, method, pos)
    end
    WhodunnitService:Recheck() -- a death drops stale votes / can tip a conviction
    self:CheckWinConditions(method)
end

-- A medic brought them back. Their role is unchanged. A person or an NPC:
-- the caller has already given them a body (LoadCharacter, or
-- BotService:Respawn), so this only marks them alive and, for an NPC, sets
-- it thinking again.
function RoundService:Revive(plr: Player): boolean
    if state ~= "ACTIVE" or alive[plr] or not self:IsParticipant(plr) or not plr.Character then
        return false
    end
    alive[plr] = true
    watchDeath(self, plr)
    table.insert(timeline, { at = os.clock() - activeStart, victim = plr.Name, method = "revived" })
    DataService:SetScreen(plr, "ACTIVE")
    broadcastAlive()
    SpectatorService:Exit(plr)
    SpectatorService:Broadcast(aliveNames())
    RoleService:Arm(plr) -- LoadCharacter took their weapon
    if Participant.IsBot(plr) then
        BotService:Wake(plr) -- its old mind stopped with its old body
    end
    return true
end

local function murdererNames(): { string }
    local names = {}
    for plr in alive do
        if RoleService:Get(plr) == "murderer" then
            table.insert(names, plr.Name)
        end
    end
    return names
end

-- Everything below runs in one coroutine, and an uncaught error inside it
-- would end that coroutine for good: the round loop simply stops and the
-- server sits in whatever state it was in until it shuts down, for everyone
-- on it. Nothing else watches the loop, so a bad tick has to be survivable
-- here. The error is logged with a traceback rather than swallowed, and the
-- round is dropped back to the lobby so the next cycle starts from a known
-- state instead of half a round.
local function recover(self, err: string)
    warn("[ColdCase] round loop error, returning to the lobby:\n" .. tostring(err))
    -- ReturnToLobby must not be able to kill the loop either
    local ok, cleanupErr = pcall(function()
        self:ReturnToLobby()
    end)
    if not ok then
        warn("[ColdCase] cleanup after that error also failed:\n" .. tostring(cleanupErr))
    end
    for _, c in diedConnections do
        c:Disconnect()
    end
    diedConnections = {}
    alive = {}
    pendingBots = 0
    self:EnterLobby()
end

function RoundService:Start()
    task.spawn(function()
        while true do
            task.wait(Config.SIGHTLINE_SAMPLE)
            local ok, err = xpcall(function()
                self:Tick()
            end, debug.traceback)
            if not ok then
                recover(self, err)
            end
        end
    end)
end

-- One tick of the round loop. Split out so Start's coroutine has something it
-- can wrap: the per-tick work matters as much as the transition, since an
-- event, a snitch reveal or a sightline sample erroring would kill the loop
-- just as dead as Advance would.
function RoundService:Tick()
    if state == "INTERMISSION" then
        self:ArmLobby()
    end
    if os.clock() < stateEnds then
        if state == "ACTIVE" then
            local left = stateEnds - os.clock()
            if not eventFired and roundLength - left >= roundLength * Config.EVENT_AT_PCT then
                eventFired = true
                EventService:FireWeighted(mapIsIndoor)
            end
            if not snitchRevealed and left <= Config.SNITCH_REVEAL_AT then
                snitchRevealed = true
                RoleService:RevealSnitch()
                SnitchService:OnReveal()
            end
            -- Last Call: coins double and the murderer is outlined for
            -- everyone. Forces an ending instead of a hide-out.
            if not lastCallFired and left <= Config.LAST_CALL_AT then
                lastCallFired = true
                EconomyService:SetLastCall(true)
                Remotes.EventFired:FireAllClients("LAST_CALL", math.ceil(left), murdererNames())
            end
            -- Witness clues need real observation time, not a facing check
            EvidenceService:SampleSightlines(aliveList(), os.clock())
        end
        -- The state has not run out yet, so there is nothing to advance
        return
    end
    self:Advance()
end

function RoundService:Advance()
    if state == "INTERMISSION" then
        -- A quiet server fills the round with NPCs around whoever is playing;
        -- players who chose to wait stay in the lobby for real players
        local plan, humans, playing = lobbyPlan()
        if not plan.start then
            self:EnterLobby() -- someone changed their mind at the last second
            return
        end
        participants = if plan.full then humans else playing
        pendingBots = plan.npcs
        lobbyArmed = false
        -- Clone the map now, so the LOADING window covers its replication
        self:BuildVotedMap()
        setState("LOADING", Config.LOADING_TIME)
    elseif state == "LOADING" then
        local wanted = pendingBots
        local joined = 0
        for _, bot in BotService:Spawn(wanted) do
            table.insert(participants, bot)
            joined += 1
        end
        pendingBots = 0
        -- Never drop someone into a round alone: if the NPCs could not be
        -- built, go back to the lobby and try again next intermission
        if wanted > 0 and #participants < minPlayers() then
            warn(
                ("[ColdCase] only %d of %d players and NPCs ready"):format(
                    #participants,
                    minPlayers()
                )
            )
            BotService:Clear()
            participants = {}
            -- The map is already standing by the time we get here, so take it
            -- back down instead of leaving it in view behind the lobby.
            local built = workspace:FindFirstChild("Round")
            if built then
                built:Destroy()
            end
            Remotes.Notify:FireAllClients("The NPCs could not join. Trying again next round.")
            self:EnterLobby()
            return
        end
        if joined > 0 then
            Remotes.Notify:FireAllClients(("%d NPCs joined this round."):format(joined))
        end
        self:PlaceParticipants()
        local present = {}
        for _, plr in participants do
            if plr.Parent == Players and plr.Character then
                table.insert(present, plr)
            end
        end
        participants = present
        self:SetMovementLocked(true)
        -- Pick the mode before roles are dealt, so RoleService can read it.
        currentMode = pickMode()
        ReplicatedStorage:SetAttribute("Mode", currentMode)
        RoleService:Assign(participants)

        alive = {}
        for _, plr in participants do
            alive[plr] = true
            watchDeath(self, plr)
        end
        broadcastAlive()
        setState("REVEAL", Config.REVEAL_TIME)
    elseif state == "REVEAL" then
        eventFired, snitchRevealed, lastCallFired = false, false, false
        self.clueCounts = {}
        timeline = {}
        EventService:TakeRoundEvent()
        EvidenceService:ResetSightlines()
        AbilityService:Reset()
        EconomyService:SetLastCall(false)
        roundLength = lengthFor(#participants)
        self:SetMovementLocked(false)
        CombatService:MarkRoundStart()
        CoinService:Arm(workspace.Round)
        activeStart = os.clock()
        OnboardingService:NoteRoundStart(participants)
        setState("ACTIVE", roundLength)
        BotService:StartRound()
        SnitchService:OnRoundStart()
        WhodunnitService:Reset()
        -- Mode effects. Hardcore dims the whole round (so it never fires a
        -- random event) and announces itself; the client reads the Mode
        -- attribute for reduced vision.
        local modeDef = Modes.Get(currentMode)
        if modeDef.dark then
            eventFired = true
            EventService:SetModeDark(true)
        end
        if currentMode ~= "classic" then
            Remotes.Notify:FireAllClients(("%s — %s"):format(modeDef.name, modeDef.blurb))
        end
    elseif state == "ACTIVE" then
        self:Resolve("innocents", "time")
    elseif state == "RESOLUTION" then
        self:ReturnToLobby()
        self:EnterLobby()
    end
end

-- Called after every elimination. `method` is how the last one went out, so a
-- murderer who disconnects is not reported to the room as one who was killed.
function RoundService:CheckWinConditions(method: string?)
    if state ~= "ACTIVE" then
        return
    end
    local murdererAlive, othersAlive = false, 0
    for plr in alive do
        if RoleService:Get(plr) == "murderer" then
            murdererAlive = true
        else
            othersAlive += 1
        end
    end
    if not murdererAlive then
        self:Resolve("innocents", method == "left" and "left" or "killed")
    elseif othersAlive == 0 then
        self:Resolve("murderer", "wiped")
    end
end

function RoundService:Resolve(winner: string, reason: string)
    if state ~= "ACTIVE" then
        return
    end
    state = "RESOLVING" -- blocks re-entry while payouts run
    AbilityService:Reset()
    local survivors = table.clone(alive)
    EconomyService:PayOut(participants, winner, survivors, self.clueCounts)
    EconomyService:SetLastCall(false)
    Remotes.RoundOver:FireAllClients(winner, reason, RoleService:GetPublicReveal(), timeline)

    for _, plr in participants do
        if plr.Parent == Players and not Participant.IsBot(plr) then
            Analytics.RoundComplete(
                plr,
                currentMapName,
                winner,
                os.clock() - activeStart,
                #participants,
                EventService:TakeRoundEvent()
            )
            break
        end
    end
    OnboardingService:NoteRoundEnd(participants)

    for _, c in diedConnections do
        c:Disconnect()
    end
    diedConnections = {}
    alive = {}
    SpectatorService:Reset()
    CoinService:Disarm()
    EventService:Clear()
    ReplicatedStorage:SetAttribute("Mode", "classic") -- lobby is never a special mode
    setState("RESOLUTION", Config.RESOLUTION_TIME)
end

function RoundService:ReturnToLobby()
    EvidenceService:Clear()
    RoleService:Clear()
    SnitchService:Clear()
    LightingMood.Apply("Lobby")
    local round = workspace:FindFirstChild("Round")
    if round then
        round:Destroy()
    end
    for _, plr in participants do
        if plr.Parent == Players and not Participant.IsBot(plr) then
            task.spawn(plr.LoadCharacter, plr)
        end
    end
    BotService:Clear()
    participants = {}
end

Players.PlayerRemoving:Connect(function(plr)
    if votes[plr] then
        votes[plr] = nil
        broadcastTally()
    end
    RoundService.clueCounts[plr] = nil
    if alive[plr] then
        RoundService:MarkDead(plr, nil, "left")
    end
end)

ReplicatedStorage:SetAttribute("RoundState", state)
ReplicatedStorage:SetAttribute("RoundEnds", 0)

-- These services need round state but RoundService requires them, so it
-- hands itself over instead of being required back (a require cycle).
CombatService:BindRound(RoundService)
EvidenceService:BindRound(RoundService)
CoinService:BindRound(RoundService)
AbilityService:BindRound(RoundService)
BotService:BindRound(RoundService)
SnitchService:BindRound(RoundService)
WhodunnitService:BindRound(RoundService)

return RoundService
