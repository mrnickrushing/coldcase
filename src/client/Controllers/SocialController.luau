-- StarterPlayerScripts/Controllers/SocialController
-- The Radio and Emote pass dock for owners (bottom left, above the evidence
-- log), and emote labels over heads for everyone. Radio lines arrive in the
-- evidence log through HudController.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Theme = require(Shared.Theme)
local ClientState = require(script.Parent.Parent.ClientState)

local plr = Players.LocalPlayer
local SocialController = {}

local EMOTE_LABEL: { [string]: string } = {
    wave = "waves",
    point = "points",
    shrug = "shrugs",
    laugh = "laughs",
    panic = "panics",
}
-- Emotes the default Animate script can play; the rest are label only
local ANIMATED: { [string]: boolean } = { wave = true, point = true, laugh = true }

local gui = Instance.new("ScreenGui")
gui.Name = "SocialDock"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.Parent = plr:WaitForChild("PlayerGui")

local dock = Instance.new("Frame")
dock.Name = "Dock"
dock.AnchorPoint = Vector2.new(0, 1)
dock.BackgroundTransparency = 1
dock.Parent = gui
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 8)
layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = dock

local function skin(inst: GuiObject, colour: Color3?)
    inst.BackgroundColor3 = colour or Theme.PANEL
    inst.BorderSizePixel = 0
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = inst
    local stroke = Instance.new("UIStroke")
    stroke.Color = Theme.STROKE
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Parent = inst
end

local function row(name: string, order: number): Frame
    local f = Instance.new("Frame")
    f.Name = name
    f.LayoutOrder = order
    f.Size = UDim2.new(1, 0, 0, Theme.TAP_MIN)
    f.BackgroundTransparency = 1
    f.Parent = dock
    return f
end

---------------------------------------------------------------- Radio
local radioRow = row("Radio", 1)

local box = Instance.new("TextBox")
box.Name = "Message"
box.Size = UDim2.new(1, -78, 1, 0)
box.Text = ""
box.PlaceholderText = "RADIO · to everyone"
box.PlaceholderColor3 = Theme.DIM
box.ClearTextOnFocus = false
box.FontFace = Theme.MONO
box.TextSize = 13
box.TextColor3 = Theme.INK
box.TextXAlignment = Enum.TextXAlignment.Left
box.TextTruncate = Enum.TextTruncate.AtEnd
skin(box)
local padding = Instance.new("UIPadding")
padding.PaddingLeft = UDim.new(0, 10)
padding.PaddingRight = UDim.new(0, 10)
padding.Parent = box
box.Parent = radioRow

local send = Instance.new("TextButton")
send.Name = "Send"
send.AnchorPoint = Vector2.new(1, 0)
send.Position = UDim2.fromScale(1, 0)
send.Size = UDim2.new(0, 70, 1, 0)
send.Text = "SEND"
send.FontFace = Theme.DISPLAY
send.TextSize = 18
send.TextColor3 = Theme.GROUND
skin(send, Theme.AMBER)
send.Parent = radioRow

local function sendRadio()
    local text = string.match(box.Text, "^%s*(.-)%s*$") or ""
    if text == "" then
        return
    end
    local cut = utf8.offset(text, Config.RADIO_MAX_CHARS + 1)
    if cut then
        text = string.sub(text, 1, cut - 1)
    end
    Remotes.RequestRadio:FireServer(text)
    box.Text = ""
end
send.Activated:Connect(sendRadio)
box.FocusLost:Connect(function(enterPressed)
    if enterPressed then
        sendRadio()
    end
end)

---------------------------------------------------------------- Emotes
local emoteRow = row("Emotes", 2)
local emoteLayout = Instance.new("UIListLayout")
emoteLayout.FillDirection = Enum.FillDirection.Horizontal
emoteLayout.Padding = UDim.new(0, 6)
emoteLayout.SortOrder = Enum.SortOrder.LayoutOrder
emoteLayout.Parent = emoteRow

for i, id in Config.EMOTES do
    local b = Instance.new("TextButton")
    b.Name = id
    b.LayoutOrder = i
    b.Size = UDim2.new(1 / #Config.EMOTES, -5, 1, 0)
    b.Text = string.upper(id)
    b.FontFace = Theme.MONO
    b.TextSize = 11
    b.TextColor3 = Theme.SOFT
    skin(b)
    b.Parent = emoteRow
    b.Activated:Connect(function()
        Remotes.RequestEmote:FireServer(id)
    end)
end

Remotes.EmotePlayed.OnClientEvent:Connect(function(who: Player, emoteId: string)
    local text = EMOTE_LABEL[emoteId]
    local char = who and who.Character
    local head = char and char:FindFirstChild("Head")
    if not (text and head and head:IsA("BasePart")) then
        return
    end
    if who == plr and ANIMATED[emoteId] then
        local animate = (char :: Model):FindFirstChild("Animate")
        local play = animate and animate:FindFirstChild("PlayEmote")
        if play and play:IsA("BindableFunction") then
            pcall(play.Invoke, play, emoteId)
        end
    end

    local old = head:FindFirstChild("EmoteTag")
    if old then
        old:Destroy()
    end
    local tag = Instance.new("BillboardGui")
    tag.Name = "EmoteTag"
    tag.Size = UDim2.fromOffset(160, 28)
    tag.StudsOffset = Vector3.new(0, 2.4, 0)
    -- Name-tag range in fog, so an emote never shows someone you could not see
    tag.MaxDistance = Config.FOG_NAMETAG_RANGE
    tag.LightInfluence = 0
    local l = Instance.new("TextLabel")
    l.Size = UDim2.fromScale(1, 1)
    l.BackgroundTransparency = 1
    l.Text = text
    l.FontFace = Theme.MONO
    l.TextSize = 14
    l.TextColor3 = Theme.INK
    l.TextStrokeTransparency = 0.5
    l.Parent = tag
    tag.Adornee = head
    tag.Parent = head
    task.delay(3, function()
        tag:Destroy()
    end)
end)

---------------------------------------------------------------- Visibility + layout
local function render()
    local passes = ClientState.data.passes or {}
    -- Mid-round only the living transmit; the server refuses the rest anyway
    local canRadio = ClientState.GetRoundState() ~= "ACTIVE"
        or (ClientState.role ~= nil and not ClientState.spectating)
    radioRow.Visible = passes.radio == true and canRadio
    emoteRow.Visible = passes.emotes == true
    -- Menus own the screen while one is open
    dock.Visible = ClientState.screen == nil and (radioRow.Visible or emoteRow.Visible)

    -- Sits above the evidence log, which collapses on narrow screens
    local camera = workspace.CurrentCamera
    local narrow = camera ~= nil and camera.ViewportSize.X < Theme.NARROW_WIDTH
    dock.Position = UDim2.new(0, 16, 1, narrow and -120 or -174)
    dock.Size = UDim2.new(0, narrow and 240 or 340, 0, Theme.TAP_MIN * 2 + 8)
end

for _, key in { "data", "role", "screen", "spectating" } do
    ClientState.On(key, render)
end
ReplicatedStorage:GetAttributeChangedSignal("RoundState"):Connect(render)

local viewportConn
local function watchCamera()
    if viewportConn then
        viewportConn:Disconnect()
    end
    local camera = workspace.CurrentCamera
    if camera then
        viewportConn = camera:GetPropertyChangedSignal("ViewportSize"):Connect(render)
    end
    render()
end
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera)
watchCamera()

return SocialController
