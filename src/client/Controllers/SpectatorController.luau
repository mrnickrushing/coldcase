-- StarterPlayerScripts/Controllers/SpectatorController
-- Dead players watch the living instead of their own body. The server sends
-- who is left; the camera is ours.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Theme = require(ReplicatedStorage:WaitForChild("Shared").Theme)
local ClientState = require(script.Parent.Parent.ClientState)

local plr = Players.LocalPlayer
local SpectatorController = {}
local targets: { string } = {}
local index, active = 1, false

local gui = Instance.new("ScreenGui")
gui.Name = "SpectatorGui"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.Enabled = false
gui.Parent = plr:WaitForChild("PlayerGui")

-- Bottom centre, clear of the middle of the screen
local bar = Instance.new("Frame")
bar.Name = "Bar"
bar.AnchorPoint = Vector2.new(0.5, 1)
bar.Position = UDim2.new(0.5, 0, 1, -24)
bar.Size = UDim2.fromOffset(360, 64)
bar.BackgroundColor3 = Theme.GROUND
bar.BackgroundTransparency = 0.15
bar.BorderSizePixel = 0
bar.Parent = gui
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 6)
corner.Parent = bar
local stroke = Instance.new("UIStroke")
stroke.Color = Theme.STROKE
stroke.Parent = bar

local function label(
    name: string,
    text: string,
    size: number,
    y: number,
    colour: Color3,
    font: Font
)
    local l = Instance.new("TextLabel")
    l.Name = name
    l.Text = text
    l.FontFace = font
    l.TextSize = size
    l.TextColor3 = colour
    l.BackgroundTransparency = 1
    l.Position = UDim2.new(0, 60, 0, y)
    l.Size = UDim2.new(1, -120, 0, size + 6)
    l.TextTruncate = Enum.TextTruncate.AtEnd
    l.Parent = bar
    return l
end

label("Caption", "SPECTATING", 10, 8, Theme.DIM, Theme.MONO)
local who = label("Who", "—", 22, 24, Theme.INK, Theme.DISPLAY)

local function arrow(name: string, glyph: string, left: boolean): TextButton
    local b = Instance.new("TextButton")
    b.Name = name
    b.Text = glyph
    b.FontFace = Theme.DISPLAY
    b.TextSize = 26
    b.TextColor3 = Theme.AMBER
    b.BackgroundTransparency = 1
    b.AnchorPoint = Vector2.new(left and 0 or 1, 0.5)
    b.Position = UDim2.new(left and 0 or 1, left and 8 or -8, 0.5, 0)
    b.Size = UDim2.fromOffset(Theme.TAP_MIN, Theme.TAP_MIN)
    b.Parent = bar
    return b
end

local function restoreCamera()
    local camera = workspace.CurrentCamera
    local hum = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
    if camera then
        camera.CameraType = Enum.CameraType.Custom
        camera.CameraSubject = hum
    end
end

local function focus()
    if not active then
        return
    end
    if #targets == 0 then
        who.Text = "NOBODY LEFT"
        restoreCamera()
        return
    end
    index = ((index - 1) % #targets) + 1
    local name = targets[index]
    local target = Players:FindFirstChild(name)
    local char: Model? = if target and target:IsA("Player") then target.Character else nil
    if not char then
        -- NPCs are not Players; find their character by name
        for _, model in CollectionService:GetTagged("BotCharacter") do
            if model:IsA("Model") and model:GetAttribute("BotName") == name then
                char = model
                break
            end
        end
    end
    who.Text = string.upper(if target and target:IsA("Player") then target.DisplayName else name)
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local camera = workspace.CurrentCamera
    if hum and camera then
        camera.CameraType = Enum.CameraType.Custom
        camera.CameraSubject = hum
    end
end

local function step(delta: number)
    if active and #targets > 0 then
        index += delta
        focus()
    end
end

arrow("Prev", "‹", true).Activated:Connect(function()
    step(-1)
end)
arrow("Next", "›", false).Activated:Connect(function()
    step(1)
end)

-- Arrow keys, not A/D: a respawned body in the lobby still walks on WASD
UserInputService.InputBegan:Connect(function(input, processed)
    if not active or processed then
        return
    end
    if input.KeyCode == Enum.KeyCode.Left or input.KeyCode == Enum.KeyCode.DPadLeft then
        step(-1)
    elseif input.KeyCode == Enum.KeyCode.Right or input.KeyCode == Enum.KeyCode.DPadRight then
        step(1)
    end
end)

local function setActive(on: boolean)
    active = on
    gui.Enabled = on
    ClientState.Set("spectating", on)
end

Remotes.Spectate.OnClientEvent:Connect(function(action: string, list: { string }?)
    if action == "enter" then
        targets, index = list or {}, 1
        setActive(true)
        focus()
    elseif action == "targets" then
        -- Keep watching the same person while they are still alive
        local current = targets[index]
        targets = list or {}
        index = (current and table.find(targets, current)) or index
        focus()
    elseif action == "exit" then
        targets = {}
        setActive(false)
        restoreCamera()
    end
end)

-- Respawning in the lobby hands the camera back to our own body; take it again
plr.CharacterAdded:Connect(function()
    if active then
        Remotes.RequestSpectate:FireServer()
        task.defer(focus)
    end
end)

ReplicatedStorage:GetAttributeChangedSignal("RoundState"):Connect(function()
    if active and ClientState.GetRoundState() ~= "ACTIVE" then
        targets = {}
        setActive(false)
        restoreCamera()
    end
end)

return SpectatorController
