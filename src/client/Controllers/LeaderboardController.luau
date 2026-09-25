--!strict
-- StarterPlayerScripts/Controllers/LeaderboardController
-- A toggleable global-leaderboard panel shown in the lobby: top round wins, top
-- murderer escapes, and richest collections. The server pushes the data over the
-- Leaderboard remote (LeaderboardService); this only renders it.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared.Theme)
local ClientState = require(script.Parent.Parent.ClientState)

local plr = Players.LocalPlayer
local ORDER = { "wins", "killer", "worth" }

local function commas(n: number): string
    local s = tostring(math.floor(n))
    return (s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
end

local gui = Instance.new("ScreenGui")
gui.Name = "LeaderboardGui"
gui.DisplayOrder = 15
gui.ResetOnSpawn = false
gui.Enabled = false
gui.Parent = plr:WaitForChild("PlayerGui")

local toggle = Instance.new("TextButton")
toggle.Name = "Toggle"
toggle.AnchorPoint = Vector2.new(0, 0)
toggle.Position = UDim2.fromOffset(16, 70)
toggle.Size = UDim2.fromOffset(150, Theme.TAP_MIN)
toggle.BackgroundColor3 = Theme.CARD
toggle.BorderSizePixel = 0
toggle.FontFace = Theme.DISPLAY
toggle.TextSize = 15
toggle.TextColor3 = Theme.AMBER
toggle.Text = "LEADERBOARD"
toggle.Parent = gui
do
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 6)
    c.Parent = toggle
    local s = Instance.new("UIStroke")
    s.Color = Theme.AMBER
    s.Transparency = 0.4
    s.Parent = toggle
end

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(0, 0)
panel.Position = UDim2.fromOffset(16, 70 + Theme.TAP_MIN + 8)
panel.Size = UDim2.fromOffset(300, 430)
panel.BackgroundColor3 = Theme.CARD
panel.BackgroundTransparency = 0.03
panel.BorderSizePixel = 0
panel.Visible = false
panel.Parent = gui
do
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 6)
    c.Parent = panel
    local s = Instance.new("UIStroke")
    s.Color = Theme.STROKE
    s.Parent = panel
    local pad = Instance.new("UIPadding")
    pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 10), UDim.new(0, 10)
    pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 10), UDim.new(0, 10)
    pad.Parent = panel
    local list = Instance.new("UIListLayout")
    list.Padding = UDim.new(0, 10)
    list.SortOrder = Enum.SortOrder.LayoutOrder
    list.Parent = panel
end

-- One section per board, rebuilt on each payload.
local sections: { [string]: Frame } = {}
for i, key in ORDER do
    local section = Instance.new("Frame")
    section.Name = key
    section.LayoutOrder = i
    section.BackgroundTransparency = 1
    section.Size = UDim2.new(1, 0, 0, 132)
    section.Parent = panel
    local sl = Instance.new("UIListLayout")
    sl.Padding = UDim.new(0, 2)
    sl.SortOrder = Enum.SortOrder.LayoutOrder
    sl.Parent = section
    sections[key] = section
end

local function label(parent: Instance, order: number, size: number, colour: Color3, font): TextLabel
    local l = Instance.new("TextLabel")
    l.LayoutOrder = order
    l.BackgroundTransparency = 1
    l.Size = UDim2.new(1, 0, 0, size + 2)
    l.FontFace = font
    l.TextSize = size
    l.TextColor3 = colour
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Parent = parent
    return l
end

local function renderBoard(key: string, board: any)
    local section = sections[key]
    for _, c in section:GetChildren() do
        if c:IsA("TextLabel") then
            c:Destroy()
        end
    end
    label(section, 1, 14, Theme.AMBER, Theme.DISPLAY).Text = (board and board.title) or key
    local rows = (board and board.rows) or {}
    if #rows == 0 then
        label(section, 2, 12, Theme.DIM, Theme.MONO).Text = "no scores yet"
        return
    end
    for i, row in rows do
        local line = label(section, i + 1, 13, Theme.INK, Theme.MONO)
        line.Text = ("%d  %-14s %s"):format(i, row.name:sub(1, 14), commas(row.value))
    end
end

Remotes.Leaderboard.OnClientEvent:Connect(function(payload)
    for _, key in ORDER do
        renderBoard(key, payload and payload[key])
    end
end)

toggle.Activated:Connect(function()
    panel.Visible = not panel.Visible
end)

-- Only in the lobby: hidden the moment a round is live or a full menu is open.
local function refresh()
    local inLobby = ClientState.GetRoundState() == "INTERMISSION"
    gui.Enabled = inLobby
    if not inLobby then
        panel.Visible = false
    end
end
ReplicatedStorage:GetAttributeChangedSignal("RoundState"):Connect(refresh)
ClientState.On("screen", refresh)
refresh()

return {}
