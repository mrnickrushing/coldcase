-- StarterPlayerScripts/Controllers/KillCamController
-- Design Bible · Resolution: "Killer revealed, kill-cam, payout." When a round
-- ends, the camera circles the murderer's last kill for a few seconds before
-- the results screen. It only runs after RoundOver, when every role is public.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Theme = require(Shared.Theme)
local ClientState = require(script.Parent.Parent.ClientState)

local plr = Players.LocalPlayer
local KillCamController = {}

local gui = Instance.new("ScreenGui")
gui.Name = "KillCam"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.Enabled = false
gui.DisplayOrder = 20
gui.Parent = plr:WaitForChild("PlayerGui")

local function bar(anchorY: number): Frame
    local f = Instance.new("Frame")
    f.AnchorPoint = Vector2.new(0, anchorY)
    f.Position = UDim2.fromScale(0, anchorY)
    f.Size = UDim2.fromScale(1, 0.13)
    f.BackgroundColor3 = Theme.GROUND
    f.BorderSizePixel = 0
    f.Parent = gui
    return f
end
bar(0)
local bottom = bar(1)

local function label(text: string, size: number, colour: Color3, font: Font, y: number): TextLabel
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1
    l.AnchorPoint = Vector2.new(0.5, 0.5)
    l.Position = UDim2.fromScale(0.5, y)
    l.Size = UDim2.new(1, -40, 0, size + 6)
    l.Text = text
    l.TextSize = size
    l.TextColor3 = colour
    l.FontFace = font
    l.Parent = bottom
    return l
end
local kicker = label("KILL-CAM", 12, Theme.AMBER, Theme.MONO, 0.28)
local title = label("—", 30, Theme.ROLE.murderer, Theme.DISPLAY, 0.66)

local function lastKill(reveal, timeline)
    local isMurderer = {}
    for name, role in reveal do
        if role == "murderer" then
            isMurderer[name] = true
        end
    end
    for i = #timeline, 1, -1 do
        local e = timeline[i]
        if e.killer and isMurderer[e.killer] and typeof(e.pos) == "Vector3" then
            return e
        end
    end
    return nil
end

local function finish()
    gui.Enabled = false
    local camera = workspace.CurrentCamera
    if camera then
        camera.CameraType = Enum.CameraType.Custom
        camera.CameraSubject = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
    end
    ClientState.Set("killcam", false)
end

Remotes.RoundOver.OnClientEvent:Connect(function(_winner, _reason, reveal, timeline)
    local kill = lastKill(reveal or {}, timeline or {})
    if not kill then
        return
    end
    ClientState.Set("killcam", true)
    kicker.Text = "KILL-CAM"
    title.Text = ("%s  ·  %s"):format(string.upper(kill.killer), string.upper(kill.victim))
    gui.Enabled = true

    local centre = kill.pos + Vector3.new(0, 1.5, 0)
    local started = os.clock()
    local conn
    conn = RunService.Heartbeat:Connect(function()
        local t = os.clock() - started
        local camera = workspace.CurrentCamera
        if t >= Config.KILLCAM_TIME or not camera then
            conn:Disconnect()
            finish()
            return
        end
        -- Re-asserted every frame: the spectator camera hands back control at round end
        local angle = t * 0.6
        camera.CameraType = Enum.CameraType.Scriptable
        camera.CFrame = CFrame.lookAt(
            centre + Vector3.new(math.cos(angle) * 16, 9, math.sin(angle) * 16),
            centre
        )
    end)
end)

return KillCamController
