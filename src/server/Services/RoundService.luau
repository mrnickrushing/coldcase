-- The heartbeat. Every transition is server-authoritative.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Config = require(ReplicatedStorage.Shared.Config)
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
local Lobby = require(ReplicatedStorage.Shared.Lobby)

local RoundService = {}
local state, stateEnds = "INTERMISSION", 0
local participants: { Player } = {} -- Players and NPCs (see Participant)
local pendingBots = 0
local votes: { [Player]: string } = {}
local alive: { [Player]: boolean } = {}
local diedConnections: { RBXScriptConnection } = {}
local eventFired, snitchRevealed, lastCallFired = false, false, false
local currentMapName, mapIsIndoor = "none", true
local activeStart, roundLength = 0, Config.ROUND_LENGTH
-- Public only after the round resolves: { at, killer?, victim, method }
local timeline: { { at: number, killer: string?, victim: string, method: string, pos: Vector3? } } =
    {}
RoundService.clueCounts = {} :: { [Player]: number }

local function setState(new: string, duration: number)
    state, stateEnds = new, os.clock() + duration
    -- Attributes let late joiners and the HUD timer sync without os.clock drift
    ReplicatedStorage:SetAttribute("RoundState", new)
    ReplicatedStorage:SetAttribute("RoundEnds", workspace:GetServerTimeNow() + duration)
    Remotes.RoundState:FireAllClients(new, duration)
    for _, plr in Players:GetPlayers() do
        DataService:SetScreen(plr, (new == "ACTIVE" and not alive[plr]) and "SPECTATING" or new)
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
    if count < 8 then
        return Config.ROUND_LENGTH_SMALL
    elseif count >= 12 then
        return Config.ROUND_LENGTH_LARGE
    end
    return Config.ROUND_LENGTH
end

function RoundService:GetState(): string
    return state
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

function RoundService:AliveNames(): { string }
    return aliveNames()
end

function RoundService:AliveParticipants(): { any }
    return aliveList()
end

function RoundService:BotFromCharacter(model: Instance): any
    return BotService:FromCharacter(model)
end

function RoundService:GetEligible(): { Player }
    local out = {}
    for _, plr in Players:GetPlayers() do
        if plr.Character and DataService:Get(plr) then
            table.insert(out, plr)
        end
    end
    return out
end

function RoundService:CastVote(plr: Player, mapName: string)
    if state ~= "INTERMISSION" or not table.find(Config.MAPS, mapName) then
        return
    end
    votes[plr] = mapName
    broadcastTally()
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

function RoundService:LoadVotedMap()
    local old = workspace:FindFirstChild("Round")
    if old then
        old:Destroy()
    end
    local folder = Instance.new("Folder")
    folder.Name = "Round"
    folder.Parent = workspace

    currentMapName = winningMap()
    mapIsIndoor = currentMapName ~= "RustedPier"
    local template = ServerStorage.Maps:FindFirstChild(currentMapName)
    if template then
        template:Clone().Parent = folder
    else
        warn("[ColdCase] missing map " .. currentMapName)
    end
    votes = {}
    broadcastTally()

    local spawns = {}
    for _, part in folder:GetDescendants() do
        if part:IsA("BasePart") and part:HasTag("SpawnPoint") then
            table.insert(spawns, part)
        end
    end
    for i = #spawns, 2, -1 do
        local j = math.random(i)
        spawns[i], spawns[j] = spawns[j], spawns[i]
    end

    -- Spawn with a minimum pairwise separation, or someone dies before they
    -- have moved. When no spawn clears the minimum, take the one farthest
    -- from everyone already placed rather than leaving a player in the lobby.
    local used = {}
    for _, plr in participants do
        local char = plr.Character
        if #spawns == 0 or not char then
            continue
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
            hum.WalkSpeed = locked and 0 or 16
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
    self:CheckWinConditions()
end

-- A medic brought them back. Their role is unchanged.
function RoundService:Revive(plr: Player): boolean
    if
        state ~= "ACTIVE"
        or alive[plr]
        or Participant.IsBot(plr)
        or not self:IsParticipant(plr)
        or not plr.Character
    then
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

function RoundService:Start()
    task.spawn(function()
        while true do
            task.wait(Config.SIGHTLINE_SAMPLE)
            if os.clock() < stateEnds then
                if state == "ACTIVE" then
                    local left = stateEnds - os.clock()
                    if
                        not eventFired
                        and roundLength - left >= roundLength * Config.EVENT_AT_PCT
                    then
                        eventFired = true
                        EventService:FireWeighted(mapIsIndoor)
                    end
                    if not snitchRevealed and left <= Config.SNITCH_REVEAL_AT then
                        snitchRevealed = true
                        RoleService:RevealSnitch()
                    end
                    -- Last Call: coins double and the murderer is outlined for
                    -- everyone. Forces an ending instead of a hide-out.
                    if not lastCallFired and left <= Config.LAST_CALL_AT then
                        lastCallFired = true
                        EconomyService:SetLastCall(true)
                        Remotes.EventFired:FireAllClients(
                            "LAST_CALL",
                            math.ceil(left),
                            murdererNames()
                        )
                    end
                    -- Witness clues need real observation time, not a facing check
                    EvidenceService:SampleSightlines(aliveList(), os.clock())
                end
                continue
            end
            self:Advance()
        end
    end)
end

function RoundService:Advance()
    if state == "INTERMISSION" then
        local humans = self:GetEligible()
        local ready = {}
        for _, plr in humans do
            if plr:GetAttribute("WaitForPlayers") ~= true then
                table.insert(ready, plr)
            end
        end
        -- A quiet server fills the round with NPCs for whoever chose to play
        -- now; players who chose to wait stay in the lobby for real players
        local plan =
            Lobby.Plan(#humans, #ready, minPlayers(), Config.BOT_FILL_TO, Config.BOTS_ENABLED)
        if not plan.start then
            setState("INTERMISSION", Config.INTERMISSION)
            return
        end
        participants = if plan.full then humans else ready
        pendingBots = plan.npcs
        setState("LOADING", Config.LOADING_TIME)
    elseif state == "LOADING" then
        for _, bot in BotService:Spawn(pendingBots) do
            table.insert(participants, bot)
        end
        pendingBots = 0
        self:LoadVotedMap()
        local present = {}
        for _, plr in participants do
            if plr.Parent == Players and plr.Character then
                table.insert(present, plr)
            end
        end
        participants = present
        self:SetMovementLocked(true)
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
    elseif state == "ACTIVE" then
        self:Resolve("innocents", "time")
    elseif state == "RESOLUTION" then
        self:ReturnToLobby()
        setState("INTERMISSION", Config.INTERMISSION)
    end
end

-- Called after every elimination
function RoundService:CheckWinConditions()
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
        self:Resolve("innocents", "killed")
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
    setState("RESOLUTION", Config.RESOLUTION_TIME)
end

function RoundService:ReturnToLobby()
    EvidenceService:Clear()
    RoleService:Clear()
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

return RoundService
