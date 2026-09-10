-- StarterPlayerScripts/Controllers/HudController
-- Drives RoundHud (Handbook §01). Builds it at runtime if StarterGui has none.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared.Theme)
local Catalog = require(Shared.Catalog)
local Config = require(Shared.Config)
local BuildHud = require(Shared.Build.BuildHud)
local ClientState = require(script.Parent.Parent.ClientState)

local ROLE_BRIEF = {
    innocent = "Survive. Read the bodies. Feed the gun.",
    sheriff = "The only honest gun here. Be certain.",
    murderer = "Take your time. Everyone is watching.",
    hero = "You took the pistol. Finish it.",
    medic = "One revive. Spend it well.",
    snitch = "They know you now. Run or fight.",
}
local STATE_LABEL = {
    INTERMISSION = "LOBBY",
    LOADING = "LOADING",
    REVEAL = "REVEAL",
    ACTIVE = "LIVE",
    RESOLUTION = "VERDICT",
}
local EMPTY = "—"

local plr = Players.LocalPlayer
local playerGui = plr:WaitForChild("PlayerGui")
local gui = playerGui:FindFirstChild("RoundHud") or BuildHud(playerGui)
local HudController = {}

local top = gui.Top
local roleTag = gui.RoleTag
local roleCard = gui.RoleCard
local banner = gui.EventBanner
local evidence = gui.Evidence
local action = gui.Action

---------------------------------------------------------------- Evidence log
-- Four lines max (two on narrow screens), newest on top, clears on round start
local entries: { { text: string, kind: string } } = {}
local narrow = false

local function renderEvidence()
    local visibleLines = narrow and 2 or 4
    for i = 1, 4 do
        local line = evidence["Line" .. i]
        local e = entries[i]
        line.Text = e and e.text or ""
        line.Bar.Visible = e ~= nil
        line.Bar.BackgroundColor3 = e and (Theme.CLUE[e.kind] or Theme.CLUE.cold) or Theme.CLUE.cold
        line.Visible = i <= visibleLines
    end
end

local function pushClue(text: string, kind: string)
    table.insert(entries, 1, { text = text, kind = kind })
    while #entries > 4 do
        table.remove(entries)
    end
    renderEvidence()
end

Remotes.Clue.OnClientEvent:Connect(function(clues)
    if clues.cold then
        pushClue("The trail has gone cold.", "cold")
        return
    end
    -- Insert in reverse so one examination still reads top-down
    for i = #clues, 1, -1 do
        pushClue(clues[i].text, clues[i].kind)
    end
end)

-- Radio pass broadcasts, filtered by the server
Remotes.RadioMessage.OnClientEvent:Connect(function(from: string, message: string)
    pushClue(("RADIO · %s: %s"):format(from, message), "radio")
end)

---------------------------------------------------------------- Roles
local cardToken = 0

local function paintRole(role: string?)
    local colour = role and Theme.ROLE[role] or Theme.MUTED
    roleTag.RoleName.Text = role and string.upper(role) or EMPTY
    roleTag.RoleName.TextColor3 = colour
    roleTag.Stroke.Color = role and colour or Theme.STROKE
end

Remotes.RoleAssigned.OnClientEvent:Connect(function(role: string, counterpart: string?)
    paintRole(role)

    if counterpart then
        -- The snitch reveal lands mid-round: never block the centre during ACTIVE
        local text = role == "snitch" and ("The murderer is %s. They know you."):format(counterpart)
            or ("%s is the snitch. They know."):format(counterpart)
        pushClue(text, "witness")
        return
    end
    if ClientState.GetRoundState() == "ACTIVE" then
        return -- promoted to hero mid-round; the RoleTag is enough
    end

    local colour = Theme.ROLE[role] or Theme.ROLE.innocent
    roleCard.RoleName.Text = string.upper(role)
    roleCard.RoleName.TextColor3 = colour
    roleCard.Brief.Text = ROLE_BRIEF[role] or ""
    roleCard.Card.Stroke.Color = colour
    roleCard.Visible = true
    cardToken += 1
    local mine = cardToken
    task.delay(Config.REVEAL_TIME, function()
        if cardToken == mine then
            roleCard.Visible = false
        end
    end)
end)

---------------------------------------------------------------- Action panel
local function renderAction()
    local role = ClientState.role
    local equipped = ClientState.data.equipped or {}
    local weaponId = nil
    if role == "murderer" then
        weaponId = equipped.knife
    elseif role == "sheriff" or role == "hero" then
        weaponId = equipped.gun
    end
    local item = weaponId and Catalog[weaponId]
    action.Weapon.Text = item and string.upper(item.name) or EMPTY
    action.Weapon.TextColor3 = item and Theme.INK or Theme.MUTED
    local prompt = ClientState.prompt
    action.Prompt.Text = (prompt and prompt ~= "") and prompt or EMPTY
end

ClientState.On("role", function(role)
    if not role then
        paintRole(nil)
        roleCard.Visible = false
    end
    renderAction()
end)
ClientState.On("prompt", renderAction)
ClientState.On("data", function(data)
    top.CoinsBox.Value.Text = tostring(data.coins or 0)
    renderAction()
end)

---------------------------------------------------------------- Top bar
Remotes.AliveChanged.OnClientEvent:Connect(function(n)
    top.AliveBox.Value.Text = tostring(n)
end)

local function onState()
    local state = ClientState.GetRoundState()
    top.StateBox.Value.Text = STATE_LABEL[state] or state
    if state == "REVEAL" then
        entries = {}
        renderEvidence()
    elseif state == "INTERMISSION" then
        top.AliveBox.Value.Text = EMPTY
    end
    if state ~= "REVEAL" then
        roleCard.Visible = false
    end
end
ReplicatedStorage:GetAttributeChangedSignal("RoundState"):Connect(onState)
onState()

local accum = 0
RunService.Heartbeat:Connect(function(dt)
    accum += dt
    if accum < 0.1 then
        return
    end
    accum = 0
    local state = ClientState.GetRoundState()
    local left = math.max(
        0,
        math.ceil((ReplicatedStorage:GetAttribute("RoundEnds") or 0) - workspace:GetServerTimeNow())
    )
    local timer = top.TimerBox.Value
    timer.Text = left > 0 and tostring(left) or EMPTY
    -- The only HUD element allowed to change colour mid-round
    timer.TextColor3 = (state == "ACTIVE" and left < 20) and Theme.DANGER or Theme.INK
end)

---------------------------------------------------------------- Event banner
-- Fades in over 0.4s, holds, fades out. No background frame.
local bannerToken = 0
local FADE = TweenInfo.new(0.4)

Remotes.EventFired.OnClientEvent:Connect(function(id: string)
    if id == "CLEAR" then
        return
    end
    bannerToken += 1
    local mine = bannerToken
    local label = banner.Label
    label.Text = (string.gsub(id, "_", " "))
    label.TextTransparency = 1
    label.TextStrokeTransparency = 1
    banner.Visible = true
    TweenService:Create(label, FADE, { TextTransparency = 0, TextStrokeTransparency = 0.7 }):Play()
    task.delay(3.2, function()
        if bannerToken ~= mine then
            return
        end
        local out =
            TweenService:Create(label, FADE, { TextTransparency = 1, TextStrokeTransparency = 1 })
        out:Play()
        out.Completed:Wait()
        if bannerToken == mine then
            banner.Visible = false
        end
    end)
end)

---------------------------------------------------------------- Layout
-- Evidence collapses under 500px. Top slides left of RoleTag when the screen
-- is too narrow to centre it without overlap.
local function fit()
    local camera = workspace.CurrentCamera
    if not camera then
        return
    end
    local vp = camera.ViewportSize
    narrow = vp.X < Theme.NARROW_WIDTH
    evidence.Size = narrow and UDim2.new(0, 240, 0, 96) or UDim2.new(0, 340, 0, 150)

    local tagWidth = narrow and 150 or 190
    roleTag.Size = UDim2.new(0, tagWidth, 0, 58)
    if vp.X >= 420 + 2 * (tagWidth + 24) then
        top.AnchorPoint = Vector2.new(0.5, 0)
        top.Position = UDim2.new(0.5, 0, 0, 14)
        top.Size = UDim2.new(0, 420, 0, 58)
    else
        top.AnchorPoint = Vector2.zero
        top.Position = UDim2.new(0, 14, 0, 14)
        top.Size = UDim2.new(0, math.clamp(vp.X - tagWidth - 38, 160, 420), 0, 58)
    end
    renderEvidence()
end

local viewportConn
local function watchCamera()
    if viewportConn then
        viewportConn:Disconnect()
    end
    local camera = workspace.CurrentCamera
    if camera then
        viewportConn = camera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
    end
    fit()
end
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera)
watchCamera()
renderAction()

return HudController
