-- StarterPlayerScripts/Controllers/LobbyController
-- Onboarding surfaces (Handbook §02): map vote open on arrival, the Locker
-- with coins shown against the price, the reveal/results card with near-miss
-- messaging, ghost hints once per account, and short toasts.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Theme = require(Shared.Theme)
local Catalog = require(Shared.Catalog)
local BuildLobby = require(Shared.Build.BuildLobby)
local ClientState = require(script.Parent.Parent.ClientState)

local plr = Players.LocalPlayer
local playerGui = plr:WaitForChild("PlayerGui")
local gui = playerGui:FindFirstChild("LobbyHud") or BuildLobby(playerGui)
local LobbyController = {}

local vote, locker, results = gui.Vote, gui.Locker, gui.Results
local FADE = TweenInfo.new(0.35)

local function mapLabel(mapName: string): string
    return string.upper((mapName:gsub("(%l)(%u)", "%1 %2")))
end

---------------------------------------------------------------- Vote
local myVote: string? = nil
local tally: { [string]: number } = {}

local function renderVote()
    for _, mapName in Config.MAPS do
        local b = vote.Options[mapName]
        b.Text = ("%s · %d"):format(mapLabel(mapName), tally[mapName] or 0)
        b.Stroke.Color = mapName == myVote and Theme.INK or Theme.STROKE
    end
end

for _, mapName in Config.MAPS do
    vote.Options[mapName].Activated:Connect(function()
        myVote = mapName
        Remotes.RequestVote:FireServer(mapName)
        renderVote()
    end)
end
Remotes.VoteTally.OnClientEvent:Connect(function(t)
    tally = t
    renderVote()
end)

---------------------------------------------------------------- Locker
-- Visible but locked when they cannot afford it: the gap is the retention loop
local function renderLocker()
    local coins = ClientState.data.coins or 0
    local canOpen = coins >= Config.CRATE_COST
    locker.Balance.Text = ("%d / %d"):format(coins, Config.CRATE_COST)
    locker.Open.Text = canOpen and ("OPEN · %d"):format(Config.CRATE_COST)
        or ("NEED %d MORE"):format(Config.CRATE_COST - coins)
    locker.Open.AutoButtonColor = canOpen
    locker.Open.TextColor3 = canOpen and Theme.INK or Theme.MUTED
end
locker.Open.Activated:Connect(function()
    if (ClientState.data.coins or 0) >= Config.CRATE_COST then
        Remotes.RequestCrate:FireServer("locker")
    end
end)
ClientState.On("data", renderLocker)

---------------------------------------------------------------- Results
local lastReward = nil

local function renderReward()
    local r = lastReward
    results.Reward.Text = r and ("+%d coins · +%d XP"):format(r.coins, r.xp) or ""
    results.NearMiss.Text = (r and r.short > 0) and ("You were %d coins short."):format(r.short)
        or ""
end

Remotes.RoundReward.OnClientEvent:Connect(function(reward)
    lastReward = reward
    renderReward()
end)

Remotes.RoundOver.OnClientEvent:Connect(
    function(winner: string, _reason: string, reveal: { [string]: string })
        local murderers = {}
        for name, role in reveal do
            if role == "murderer" then
                table.insert(murderers, name)
            end
        end
        table.sort(murderers)
        results.Title.Text = winner == "murderer" and "THE MURDERER WINS" or "THE INNOCENTS WIN"
        results.Reveal.Text = #murderers > 1
                and ("%s WERE THE MURDERERS"):format(table.concat(murderers, " & "))
            or ("%s WAS THE MURDERER"):format(murderers[1] or "NOBODY")
        results.Reveal.TextColor3 = Theme.ROLE.murderer
        results.Visible = true
        renderReward()
    end
)

---------------------------------------------------------------- Toasts
local queue: { string } = {}
local toasting = false

local function toast(text: string)
    table.insert(queue, text)
    if toasting then
        return
    end
    toasting = true
    task.spawn(function()
        while #queue > 0 do
            gui.Toast.Text = table.remove(queue, 1)
            TweenService
                :Create(gui.Toast, FADE, { TextTransparency = 0, TextStrokeTransparency = 0.7 })
                :Play()
            task.wait(2.6)
            local out = TweenService:Create(
                gui.Toast,
                FADE,
                { TextTransparency = 1, TextStrokeTransparency = 1 }
            )
            out:Play()
            out.Completed:Wait()
        end
        toasting = false
    end)
end

Remotes.Notify.OnClientEvent:Connect(toast)
Remotes.CrateResult.OnClientEvent:Connect(function(r)
    if r.announce then
        toast(("%s pulled %s · %s"):format(r.player, r.item, string.upper(r.rarity)))
        return
    end
    if r.gift then
        return -- the server's Notify names the gift
    end
    local item = Catalog[r.id]
    local name = item and string.upper(item.name) or "?"
    if r.crafted then
        toast(("CRAFTED %s · %s"):format(name, string.upper(r.rarity)))
    else
        toast(
            ("%sYOU PULLED %s · %s"):format(
                r.free and "FREE CRATE · " or "",
                name,
                string.upper(r.rarity)
            )
        )
    end
end)

---------------------------------------------------------------- Hints
-- Three ghost prompts, once each per account. No tutorial level.
local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local HINT_TEXT = {
    move = touch and "Drag the thumbstick to move" or "WASD to move",
    examine = touch and "Tap USE to examine a body" or "E to examine a body",
    coins = "Coins are on the floor",
}
local shown: { [string]: boolean } = {}
local hintBusy = false

local function showHint(id: string)
    if shown[id] or not ClientState.loaded or ClientState.data.hintsSeen[id] then
        return
    end
    while hintBusy do
        task.wait(0.25)
    end
    if shown[id] then
        return
    end
    shown[id] = true
    hintBusy = true
    gui.Hint.Text = HINT_TEXT[id]
    TweenService:Create(gui.Hint, FADE, { TextTransparency = 0.15 }):Play()
    task.wait(3.5)
    local out = TweenService:Create(gui.Hint, FADE, { TextTransparency = 1 })
    out:Play()
    out.Completed:Wait()
    hintBusy = false
    ClientState.data.hintsSeen[id] = true
    Remotes.HintSeen:FireServer(id)
end

task.spawn(function()
    while true do
        task.wait(0.25)
        if ClientState.GetRoundState() ~= "ACTIVE" or not ClientState.role or shown.examine then
            continue
        end
        local char = plr.Character
        if not char then
            continue
        end
        local here = char:GetPivot().Position
        for _, body in CollectionService:GetTagged("Body") do
            if
                body:IsA("Model")
                and (body:GetPivot().Position - here).Magnitude <= Config.EXAMINE_RANGE * 2
            then
                task.spawn(showHint, "examine")
                break
            end
        end
    end
end)

---------------------------------------------------------------- State
local function onState()
    local state = ClientState.GetRoundState()
    vote.Visible = state == "INTERMISSION"
    locker.Visible = state == "INTERMISSION" or state == "RESOLUTION"
    if state ~= "RESOLUTION" then
        results.Visible = false
    end
    if state == "INTERMISSION" then
        myVote, tally, lastReward = nil, {}, nil
        renderVote()
    elseif state == "ACTIVE" and ClientState.role then
        task.spawn(showHint, "move")
        task.delay(6, function()
            if ClientState.GetRoundState() == "ACTIVE" then
                showHint("coins")
            end
        end)
    end
end
ReplicatedStorage:GetAttributeChangedSignal("RoundState"):Connect(onState)
onState()
renderVote()
renderLocker()

return LobbyController
