--!strict
-- StarterPlayerScripts/Controllers/DeductionController
-- The snitch's suspect board (right edge, ACTIVE round only) and the one-use
-- EXPOSE button. Also the universal receiver for an Expose: when the killer is
-- named, EVERY client shows the banner and lights the killer up in red.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared.Theme)
local ClientState = require(script.Parent.Parent.ClientState)

local plr = Players.LocalPlayer
local DeductionController = {}

local BAR_COLOUR = {
    [0] = Theme.DIM, -- cleared
    [1] = Theme.SOFT, -- unknown
    [2] = Theme.AMBER, -- person of interest
    [3] = Theme.DANGER, -- likely
    [4] = Theme.DANGER, -- near-certain
}

local latest: { suspects: { any }, canExpose: boolean, used: boolean } =
    { suspects = {}, canExpose = false, used = false }

---------------------------------------------------------------- Board UI
local gui = Instance.new("ScreenGui")
gui.Name = "DeductionGui"
gui.ResetOnSpawn = false
gui.Enabled = false
gui.Parent = plr:WaitForChild("PlayerGui")

local panel = Instance.new("Frame")
panel.Name = "Board"
panel.AnchorPoint = Vector2.new(1, 0.5)
panel.Position = UDim2.new(1, -16, 0.5, 0)
panel.Size = UDim2.fromOffset(224, 300)
panel.BackgroundColor3 = Theme.CARD
panel.BackgroundTransparency = 0.06
panel.BorderSizePixel = 0
panel.Parent = gui
do
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 6)
    c.Parent = panel
    local s = Instance.new("UIStroke")
    s.Color = Theme.STROKE
    s.Parent = panel
    local pad = Instance.new("UIPadding")
    pad.PaddingTop = UDim.new(0, 10)
    pad.PaddingBottom = UDim.new(0, 10)
    pad.PaddingLeft = UDim.new(0, 10)
    pad.PaddingRight = UDim.new(0, 10)
    pad.Parent = panel
    local list = Instance.new("UIListLayout")
    list.Padding = UDim.new(0, 6)
    list.SortOrder = Enum.SortOrder.LayoutOrder
    list.Parent = panel
end

local function label(name: string, order: number, size: number, colour: Color3, font): TextLabel
    local l = Instance.new("TextLabel")
    l.Name = name
    l.LayoutOrder = order
    l.BackgroundTransparency = 1
    l.Size = UDim2.new(1, 0, 0, size)
    l.FontFace = font
    l.TextSize = size
    l.TextColor3 = colour
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Parent = panel
    return l
end

label("Title", 1, 14, Theme.INK, Theme.DISPLAY).Text = "INFORMANT · SUSPECTS"
local hint = label("Hint", 2, 12, Theme.DIM, Theme.MONO)
hint.Text = "Examine bodies to gather clues."

local rowsHolder = Instance.new("Frame")
rowsHolder.Name = "Rows"
rowsHolder.LayoutOrder = 3
rowsHolder.BackgroundTransparency = 1
rowsHolder.Size = UDim2.new(1, 0, 0, 176)
rowsHolder.Parent = panel
do
    local rl = Instance.new("UIListLayout")
    rl.Padding = UDim.new(0, 4)
    rl.SortOrder = Enum.SortOrder.LayoutOrder
    rl.Parent = rowsHolder
end

local expose = Instance.new("TextButton")
expose.Name = "Expose"
expose.LayoutOrder = 4
expose.Size = UDim2.new(1, 0, 0, Theme.TAP_MIN)
expose.AutoButtonColor = false
expose.BorderSizePixel = 0
expose.FontFace = Theme.DISPLAY
expose.TextSize = 16
expose.Text = "EXPOSE THE KILLER"
expose.TextColor3 = Theme.GROUND
expose.BackgroundColor3 = Theme.DANGER
expose.Parent = panel
do
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 6)
    c.Parent = expose
end

local function renderRows()
    for _, ch in rowsHolder:GetChildren() do
        if ch:IsA("Frame") then
            ch:Destroy()
        end
    end
    hint.Visible = #latest.suspects == 0
    for i, s in latest.suspects do
        local colour = BAR_COLOUR[s.bar] or Theme.SOFT
        local row = Instance.new("Frame")
        row.LayoutOrder = i
        row.Size = UDim2.new(1, 0, 0, 26)
        row.BackgroundColor3 = Theme.PANEL
        row.BorderSizePixel = 0
        row.Parent = rowsHolder
        local rc = Instance.new("UICorner")
        rc.CornerRadius = UDim.new(0, 4)
        rc.Parent = row
        -- confidence fill behind the text
        local fill = Instance.new("Frame")
        fill.Size = UDim2.new(s.bar / 4, 0, 1, 0)
        fill.BackgroundColor3 = colour
        fill.BackgroundTransparency = 0.72
        fill.BorderSizePixel = 0
        fill.Parent = row
        local fc = Instance.new("UICorner")
        fc.CornerRadius = UDim.new(0, 4)
        fc.Parent = fill
        local nm = Instance.new("TextLabel")
        nm.BackgroundTransparency = 1
        nm.Position = UDim2.fromOffset(8, 0)
        nm.Size = UDim2.new(0.5, -8, 1, 0)
        nm.FontFace = Theme.MONO
        nm.TextSize = 13
        nm.TextColor3 = Theme.INK
        nm.TextXAlignment = Enum.TextXAlignment.Left
        nm.TextTruncate = Enum.TextTruncate.AtEnd
        nm.Text = s.name
        nm.Parent = row
        local lb = Instance.new("TextLabel")
        lb.BackgroundTransparency = 1
        lb.AnchorPoint = Vector2.new(1, 0)
        lb.Position = UDim2.new(1, -8, 0, 0)
        lb.Size = UDim2.new(0.5, -8, 1, 0)
        lb.FontFace = Theme.MONO
        lb.TextSize = 11
        lb.TextColor3 = colour
        lb.TextXAlignment = Enum.TextXAlignment.Right
        lb.Text = string.upper(s.label)
        lb.Parent = row
    end
end

local function renderExpose()
    if latest.used then
        expose.Text = "EXPOSED"
        expose.BackgroundColor3 = Theme.STROKE
        expose.TextColor3 = Theme.DIM
        expose.Active = false
    elseif latest.canExpose then
        expose.Text = "EXPOSE THE KILLER"
        expose.BackgroundColor3 = Theme.DANGER
        expose.TextColor3 = Theme.GROUND
        expose.Active = true
    else
        expose.Text = "NOT ENOUGH YET"
        expose.BackgroundColor3 = Theme.PANEL
        expose.TextColor3 = Theme.DIM
        expose.Active = false
    end
end

expose.Activated:Connect(function()
    if latest.canExpose and not latest.used then
        Remotes.RequestExpose:FireServer()
    end
end)

local function visible(): boolean
    return ClientState.role == "snitch"
        and ClientState.GetRoundState() == "ACTIVE"
        and not ClientState.spectating
        and ClientState.screen == nil
end

local function refresh()
    gui.Enabled = visible()
end

Remotes.Deduction.OnClientEvent:Connect(function(payload)
    latest = payload
    renderRows()
    renderExpose()
    refresh()
end)

for _, key in { "role", "screen", "spectating" } do
    ClientState.On(key, refresh)
end
ReplicatedStorage:GetAttributeChangedSignal("RoundState"):Connect(refresh)

---------------------------------------------------------------- Expose (all clients)
local function charFor(name: string): Model?
    for _, p in Players:GetPlayers() do
        if p.Name == name and p.Character then
            return p.Character
        end
    end
    for _, model in CollectionService:GetTagged("BotCharacter") do
        if model:IsA("Model") and (model:GetAttribute("BotName") == name or model.Name == name) then
            return model
        end
    end
    return nil
end

local banner = Instance.new("ScreenGui")
banner.Name = "ExposeBanner"
banner.ResetOnSpawn = false
banner.DisplayOrder = 20
banner.Enabled = false
banner.Parent = plr:WaitForChild("PlayerGui")
local bannerLabel = Instance.new("TextLabel")
bannerLabel.AnchorPoint = Vector2.new(0.5, 0)
bannerLabel.Position = UDim2.fromScale(0.5, 0.14)
bannerLabel.Size = UDim2.fromOffset(720, 56)
bannerLabel.BackgroundTransparency = 1
bannerLabel.FontFace = Theme.DISPLAY
bannerLabel.TextSize = 40
bannerLabel.TextColor3 = Theme.DANGER
bannerLabel.TextStrokeTransparency = 0.4
bannerLabel.Text = ""
bannerLabel.Parent = banner

local bannerToken = 0

Remotes.Expose.OnClientEvent:Connect(function(names: { string }, seconds: number)
    if type(names) ~= "table" or #names == 0 then
        return
    end
    bannerLabel.Text = ("THE KILLER: %s"):format(table.concat(names, " & "))
    banner.Enabled = true
    bannerToken += 1
    local mine = bannerToken
    task.delay(seconds, function()
        if bannerToken == mine then
            banner.Enabled = false
        end
    end)
    for _, name in names do
        local char = charFor(name)
        if char then
            local old = char:FindFirstChild("ExposeGlow")
            if old then
                old:Destroy()
            end
            local hl = Instance.new("Highlight")
            hl.Name = "ExposeGlow"
            hl.FillColor = Theme.DANGER
            hl.OutlineColor = Theme.DANGER
            hl.FillTransparency = 0.4
            hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            hl.Adornee = char
            hl.Parent = char
            task.delay(seconds, function()
                if hl.Parent then
                    hl:Destroy()
                end
            end)
        end
    end
end)

return DeductionController
