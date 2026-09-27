--!strict
-- StarterPlayerScripts/Controllers/CompassController
-- A heading ribbon across the top of the screen so players can orient
-- themselves - find their way back to the lobby, call out a direction, or say
-- which way the killer ran. Purely cosmetic: it reads the camera's facing and
-- draws N/E/S/W ticks that scroll as you turn. Hidden while a full-screen menu
-- is open. Client-only; the server never sees or trusts it.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Theme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Theme"))
local ClientState = require(script.Parent.Parent.ClientState)

local plr = Players.LocalPlayer
local CompassController = {}

local WIDTH = 300 -- ribbon window width in pixels
local ARC = 160 -- how many degrees of heading the window spans
local PX_PER_DEG = WIDTH / ARC

-- Eight cardinal/inter-cardinal marks. Heading 0 = facing -Z (north), matching
-- the clue directions EvidenceService reports, so "north" means the same thing.
local MARKS = {
    { deg = 0, label = "N" },
    { deg = 45, label = "NE" },
    { deg = 90, label = "E" },
    { deg = 135, label = "SE" },
    { deg = 180, label = "S" },
    { deg = 225, label = "SW" },
    { deg = 270, label = "W" },
    { deg = 315, label = "NW" },
}

local gui = Instance.new("ScreenGui")
gui.Name = "ColdCaseCompass"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.DisplayOrder = 12
gui.Enabled = false
gui.Parent = plr:WaitForChild("PlayerGui")

local window = Instance.new("Frame")
window.Name = "Window"
window.AnchorPoint = Vector2.new(0.5, 0)
window.Position = UDim2.new(0.5, 0, 0, 8)
window.Size = UDim2.fromOffset(WIDTH, 34)
window.BackgroundColor3 = Theme.GROUND
window.BackgroundTransparency = 0.35
window.BorderSizePixel = 0
window.ClipsDescendants = true
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 6)
corner.Parent = window
local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromHex("1f252e")
stroke.Parent = window
window.Parent = gui

-- One reusable label per mark; RenderStepped only moves them.
local labels: { [number]: TextLabel } = {}
for i, mark in MARKS do
    local l = Instance.new("TextLabel")
    l.Name = mark.label
    l.AnchorPoint = Vector2.new(0.5, 0.5)
    l.Position = UDim2.new(0.5, 0, 0.5, 0)
    l.Size = UDim2.fromOffset(40, 24)
    l.BackgroundTransparency = 1
    l.Text = mark.label
    l.FontFace = Theme.DISPLAY
    l.TextSize = if #mark.label == 1 then 18 else 12
    l.TextColor3 = if mark.label == "N" then Theme.AMBER else Theme.SOFT
    l.Parent = window
    labels[i] = l
end

-- Centre pointer: a small notch marking the heading you actually face.
local pointer = Instance.new("Frame")
pointer.Name = "Pointer"
pointer.AnchorPoint = Vector2.new(0.5, 1)
pointer.Position = UDim2.new(0.5, 0, 1, 0)
pointer.Size = UDim2.fromOffset(2, 12)
pointer.BackgroundColor3 = Theme.AMBER
pointer.BorderSizePixel = 0
pointer.Parent = window

-- Signed shortest angle from heading to a mark, in [-180, 180].
local function delta(markDeg: number, heading: number): number
    local d = (markDeg - heading + 540) % 360 - 180
    return d
end

RunService.RenderStepped:Connect(function()
    local cam = workspace.CurrentCamera
    local shown = cam ~= nil and plr.Character ~= nil and ClientState.screen == nil
    gui.Enabled = shown
    if not shown then
        return
    end
    local look = (cam :: Camera).CFrame.LookVector
    local heading = math.deg(math.atan2(look.X, -look.Z)) % 360
    for i, mark in MARKS do
        local off = delta(mark.deg, heading) * PX_PER_DEG
        local l = labels[i]
        l.Position = UDim2.new(0.5, off, 0.5, 0)
        -- fade the ones near the clipped edges so the ribbon reads cleanly
        l.TextTransparency = math.clamp((math.abs(off) - WIDTH / 2 + 30) / 30, 0, 1)
    end
end)

return CompassController
