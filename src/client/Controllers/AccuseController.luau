--!strict
-- StarterPlayerScripts/Controllers/AccuseController
-- Whodunnit only: a panel to name the killer. Every living player sees the
-- living suspects with a running vote count; tap one to accuse (tap again to
-- change). A majority conviction of the real murderer wins the round. The server
-- (WhodunnitService) owns the tally and pushes it over AccuseTally.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared.Theme)
local ClientState = require(script.Parent.Parent.ClientState)

local plr = Players.LocalPlayer
local latest: { suspects: { string }, counts: { [string]: number } } =
    { suspects = {}, counts = {} }
local myVote: string? = nil

local gui = Instance.new("ScreenGui")
gui.Name = "AccuseGui"
gui.ResetOnSpawn = false
gui.Enabled = false
gui.Parent = plr:WaitForChild("PlayerGui")

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(0, 0.5)
panel.Position = UDim2.new(0, 16, 0.5, 0)
panel.Size = UDim2.fromOffset(210, 300)
panel.BackgroundColor3 = Theme.CARD
panel.BackgroundTransparency = 0.05
panel.BorderSizePixel = 0
panel.Parent = gui
do
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 6)
    c.Parent = panel
    local s = Instance.new("UIStroke")
    s.Color = Theme.DANGER
    s.Transparency = 0.3
    s.Parent = panel
    local pad = Instance.new("UIPadding")
    pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 10), UDim.new(0, 10)
    pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 10), UDim.new(0, 10)
    pad.Parent = panel
    local list = Instance.new("UIListLayout")
    list.Padding = UDim.new(0, 4)
    list.SortOrder = Enum.SortOrder.LayoutOrder
    list.Parent = panel
end

local title = Instance.new("TextLabel")
title.LayoutOrder = 0
title.BackgroundTransparency = 1
title.Size = UDim2.new(1, 0, 0, 18)
title.FontFace = Theme.DISPLAY
title.TextSize = 15
title.TextColor3 = Theme.DANGER
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "WHODUNNIT · NAME THE KILLER"
title.TextWrapped = true
title.Parent = panel

local rowsHolder = Instance.new("Frame")
rowsHolder.Name = "Rows"
rowsHolder.LayoutOrder = 1
rowsHolder.BackgroundTransparency = 1
rowsHolder.Size = UDim2.new(1, 0, 1, -22)
rowsHolder.Parent = panel
do
    local rl = Instance.new("UIListLayout")
    rl.Padding = UDim.new(0, 4)
    rl.SortOrder = Enum.SortOrder.LayoutOrder
    rl.Parent = rowsHolder
end

local function accuse(name: string)
    myVote = name
    Remotes.RequestAccuse:FireServer(name)
end

local function render()
    for _, c in rowsHolder:GetChildren() do
        if c:IsA("TextButton") then
            c:Destroy()
        end
    end
    local order = 0
    for _, name in latest.suspects do
        if name == plr.Name then
            continue -- you cannot accuse yourself
        end
        order += 1
        local count = latest.counts[name] or 0
        local mine = myVote == name
        local row = Instance.new("TextButton")
        row.Name = name
        row.LayoutOrder = order
        row.Size = UDim2.new(1, 0, 0, 28)
        row.AutoButtonColor = false
        row.BackgroundColor3 = mine and Theme.DANGER or Theme.PANEL
        row.BackgroundTransparency = mine and 0.35 or 0
        row.BorderSizePixel = 0
        row.FontFace = Theme.MONO
        row.TextSize = 13
        row.TextColor3 = Theme.INK
        row.Text = ""
        row.Parent = rowsHolder
        local rc = Instance.new("UICorner")
        rc.CornerRadius = UDim.new(0, 4)
        rc.Parent = row
        local nm = Instance.new("TextLabel")
        nm.BackgroundTransparency = 1
        nm.Position = UDim2.fromOffset(8, 0)
        nm.Size = UDim2.new(1, -44, 1, 0)
        nm.FontFace = Theme.MONO
        nm.TextSize = 13
        nm.TextColor3 = Theme.INK
        nm.TextXAlignment = Enum.TextXAlignment.Left
        nm.TextTruncate = Enum.TextTruncate.AtEnd
        nm.Text = name
        nm.Parent = row
        local ct = Instance.new("TextLabel")
        ct.BackgroundTransparency = 1
        ct.AnchorPoint = Vector2.new(1, 0)
        ct.Position = UDim2.new(1, -8, 0, 0)
        ct.Size = UDim2.fromOffset(30, 28)
        ct.FontFace = Theme.DISPLAY
        ct.TextSize = 15
        ct.TextColor3 = count > 0 and Theme.DANGER or Theme.DIM
        ct.Text = tostring(count)
        ct.Parent = row
        row.Activated:Connect(function()
            accuse(name)
            render()
        end)
    end
end

local function visible(): boolean
    return ReplicatedStorage:GetAttribute("Mode") == "whodunnit"
        and ClientState.GetRoundState() == "ACTIVE"
        and ClientState.role ~= nil
        and not ClientState.spectating
        and ClientState.screen == nil
end

local function refresh()
    gui.Enabled = visible()
end

Remotes.AccuseTally.OnClientEvent:Connect(function(payload)
    latest = payload or { suspects = {}, counts = {} }
    -- your vote is void once its target is gone
    if myVote and not table.find(latest.suspects, myVote) then
        myVote = nil
    end
    render()
    refresh()
end)

for _, key in { "role", "screen", "spectating" } do
    ClientState.On(key, refresh)
end
ReplicatedStorage:GetAttributeChangedSignal("RoundState"):Connect(refresh)
ReplicatedStorage:GetAttributeChangedSignal("Mode"):Connect(function()
    if ReplicatedStorage:GetAttribute("Mode") ~= "whodunnit" then
        myVote = nil
    end
    refresh()
end)

return {}
