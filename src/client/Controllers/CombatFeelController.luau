--!strict
-- StarterPlayerScripts/Controllers/CombatFeelController
-- COLD CASE · combat feel. Client-only feedback that makes a blow land:
--   * a camera kick (Humanoid.CameraOffset, so it never fights the camera),
--     shared out so InputController can kick on firing and stabbing;
--   * a hitmarker + "ELIMINATED" line when you kill someone - the server
--     tells the killer through KillConfirm;
--   * a red vignette + heavier kick when you die.
-- Nothing here is authoritative. It only reacts to what the server decided.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Theme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Theme"))

local plr = Players.LocalPlayer
local playerGui = plr:WaitForChild("PlayerGui")

local CombatFeel = {}

---------------------------------------------------------------- camera kick
local shake = { start = 0, dur = 0, mag = 0 }

local function humanoid(): Humanoid?
    local c = plr.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end

-- A decaying random kick. Overlapping calls take the stronger, longer one.
function CombatFeel.Kick(magnitude: number, duration: number)
    local now = os.clock()
    if magnitude >= shake.mag or now + duration > shake.start + shake.dur then
        shake = { start = now, dur = duration, mag = magnitude }
    end
end

RunService.RenderStepped:Connect(function()
    local hum = humanoid()
    if not hum then
        return
    end
    local t = os.clock() - shake.start
    if t >= shake.dur then
        if hum.CameraOffset.Magnitude > 0.01 then
            hum.CameraOffset = hum.CameraOffset * 0.5
        else
            hum.CameraOffset = Vector3.zero
        end
        return
    end
    local m = shake.mag * (1 - t / shake.dur)
    hum.CameraOffset = Vector3.new(
        (math.random() - 0.5) * 2 * m,
        (math.random() - 0.5) * 2 * m,
        (math.random() - 0.5) * 2 * m * 0.5
    )
end)

---------------------------------------------------------------- overlay gui
local gui = Instance.new("ScreenGui")
gui.Name = "CombatFeel"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 20
gui.Parent = playerGui

-- Red vignette: an image-free tint that flashes and fades on death
local vignette = Instance.new("Frame")
vignette.Name = "Vignette"
vignette.Size = UDim2.fromScale(1, 1)
vignette.BackgroundColor3 = Theme.DANGER
vignette.BackgroundTransparency = 1
vignette.BorderSizePixel = 0
vignette.ZIndex = 1
vignette.Parent = gui

-- Hitmarker: four ticks forming an X, popped on a kill
local marker = Instance.new("Frame")
marker.Name = "Hitmarker"
marker.AnchorPoint = Vector2.new(0.5, 0.5)
marker.Position = UDim2.fromScale(0.5, 0.5)
marker.Size = UDim2.fromOffset(34, 34)
marker.BackgroundTransparency = 1
marker.ZIndex = 3
marker.Visible = false
marker.Parent = gui
for _, rot in { 45, 135, 225, 315 } do
    local tick = Instance.new("Frame")
    tick.AnchorPoint = Vector2.new(0.5, 0.5)
    tick.Position = UDim2.fromScale(0.5, 0.5)
    tick.Size = UDim2.fromOffset(3, 12)
    tick.BackgroundColor3 = Theme.INK
    tick.BorderSizePixel = 0
    tick.Rotation = rot
    tick.ZIndex = 3
    -- push each tick outward along its rotation
    local rad = math.rad(rot)
    tick.Position = UDim2.new(0.5, math.sin(rad) * 12, 0.5, -math.cos(rad) * 12)
    tick.Parent = marker
end

-- "ELIMINATED · ROLE" line under the hitmarker
local killText = Instance.new("TextLabel")
killText.Name = "KillText"
killText.AnchorPoint = Vector2.new(0.5, 0.5)
killText.Position = UDim2.fromScale(0.5, 0.58)
killText.Size = UDim2.fromOffset(360, 28)
killText.BackgroundTransparency = 1
killText.FontFace = Theme.DISPLAY
killText.TextSize = 20
killText.TextColor3 = Theme.INK
killText.TextTransparency = 1
killText.Text = ""
killText.ZIndex = 3
killText.Parent = gui

local ROLE_COLOUR = Theme.ROLE

---------------------------------------------------------------- death flash
local function flashDeath()
    CombatFeel.Kick(0.9, 0.45)
    vignette.BackgroundTransparency = 0.35
    TweenService:Create(
        vignette,
        TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { BackgroundTransparency = 1 }
    ):Play()
end

local function watchCharacter(char: Model)
    local hum = char:WaitForChild("Humanoid", 5)
    if hum and hum:IsA("Humanoid") then
        hum.Died:Connect(flashDeath)
    end
end
if plr.Character then
    task.spawn(watchCharacter, plr.Character)
end
plr.CharacterAdded:Connect(watchCharacter)

---------------------------------------------------------------- kill confirm
local function confirmKill(victimRole: string?)
    CombatFeel.Kick(0.35, 0.16)
    -- hitmarker pop
    marker.Visible = true
    marker.Size = UDim2.fromOffset(20, 20)
    for _, tick in marker:GetChildren() do
        if tick:IsA("Frame") then
            tick.BackgroundTransparency = 0
        end
    end
    TweenService
        :Create(marker, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Size = UDim2.fromOffset(40, 40),
        })
        :Play()
    task.delay(0.28, function()
        for _, tick in marker:GetChildren() do
            if tick:IsA("Frame") then
                TweenService:Create(tick, TweenInfo.new(0.25), { BackgroundTransparency = 1 })
                    :Play()
            end
        end
    end)
    -- kill line
    local role = victimRole and victimRole:upper() or "TARGET"
    killText.Text = "ELIMINATED · " .. role
    killText.TextColor3 = (victimRole and ROLE_COLOUR[victimRole]) or Theme.INK
    killText.TextTransparency = 0
    killText.Position = UDim2.fromScale(0.5, 0.58)
    TweenService
        :Create(killText, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            TextTransparency = 1,
            Position = UDim2.fromScale(0.5, 0.55),
        })
        :Play()
end

Remotes:WaitForChild("KillConfirm").OnClientEvent:Connect(confirmKill)

return CombatFeel
