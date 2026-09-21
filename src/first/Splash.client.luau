--!strict
-- ReplicatedFirst/Splash (LocalScript)
-- The first thing a player sees. This runs before ReplicatedStorage has
-- replicated, so it carries its own palette (a copy of Shared/Theme's) and
-- builds its own gui, then holds the screen until the game is really ready:
-- the world loaded, Shared and Remotes here, the fonts and sound cues cached,
-- the profile in and the HUD built. The bar shows that work, not a timer.
local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

ReplicatedFirst:RemoveDefaultLoadingScreen()

local GROUND = Color3.fromHex("0b0d10")
local PANEL = Color3.fromHex("12151a")
local SUNK = Color3.fromHex("0f1318")
local STROKE = Color3.fromHex("262d36")
local INK = Color3.fromHex("e8e6e1")
local SOFT = Color3.fromHex("a9afb7")
local MUTED = Color3.fromHex("8b9199")
local DIM = Color3.fromHex("7d858f")
local AMBER = Color3.fromHex("f2a63b")
local DISPLAY = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Bold)
local MONO = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Medium)

local MIN_SHOWN = 1.8 -- seconds; a splash that flashes past reads as a glitch
local PATIENCE = 12 -- seconds to wait on any one step before moving on without it

local plr = Players.LocalPlayer
local playerGui = plr:WaitForChild("PlayerGui")

---------------------------------------------------------------- Build
local gui = Instance.new("ScreenGui")
gui.Name = "Splash"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 100
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

-- One canvas so the whole screen fades as a piece at the end
local canvas = Instance.new("CanvasGroup")
canvas.Name = "Canvas"
canvas.Size = UDim2.fromScale(1, 1)
canvas.BackgroundColor3 = GROUND
canvas.BorderSizePixel = 0
canvas.Active = true -- swallow taps: nothing under here is ready to be tapped
canvas.Parent = gui

-- Depth: the dark lifts slightly toward the top, like a lit room seen from a hall
local wash = Instance.new("Frame")
wash.Name = "Wash"
wash.Size = UDim2.fromScale(1, 1)
wash.BackgroundColor3 = PANEL
wash.BorderSizePixel = 0
wash.Parent = canvas
local washGradient = Instance.new("UIGradient")
washGradient.Rotation = 90
washGradient.Transparency = NumberSequence.new({
    NumberSequenceKeypoint.new(0, 0.35),
    NumberSequenceKeypoint.new(0.55, 1),
    NumberSequenceKeypoint.new(1, 1),
})
washGradient.Parent = wash

local function label(
    name: string,
    text: string,
    size: number,
    colour: Color3,
    font: Font
): TextLabel
    local l = Instance.new("TextLabel")
    l.Name = name
    l.Text = text
    l.FontFace = font
    l.TextSize = size
    l.TextColor3 = colour
    l.BackgroundTransparency = 1
    l.AnchorPoint = Vector2.new(0.5, 0.5)
    l.TextXAlignment = Enum.TextXAlignment.Center
    l.Parent = canvas
    return l
end

-- Everything sits on the centre line, in a column the eye reads top to bottom:
-- the file's caption, the name, an amber mark, the line that sets the tone,
-- then what is being done and the bar that shows it.
local caption = label("Caption", "CASE FILE", 14, MUTED, MONO)
caption.Position = UDim2.fromScale(0.5, 0.355)
caption.Size = UDim2.fromOffset(400, 20)

local title = label("Title", "COLD CASE", 112, INK, DISPLAY)
title.Position = UDim2.fromScale(0.5, 0.445)
title.Size = UDim2.fromOffset(900, 120)
title.TextScaled = true
local titleFit = Instance.new("UITextSizeConstraint")
titleFit.MaxTextSize = 112
titleFit.MinTextSize = 48
titleFit.Parent = title
-- A slow amber sheen crosses the name while the screen holds. A gradient on
-- the text, its offset tweened; the eye reads it as light moving over the sign.
local sheen = Instance.new("UIGradient")
sheen.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, INK),
    ColorSequenceKeypoint.new(0.42, INK),
    ColorSequenceKeypoint.new(0.5, AMBER),
    ColorSequenceKeypoint.new(0.58, INK),
    ColorSequenceKeypoint.new(1, INK),
})
sheen.Offset = Vector2.new(-1, 0)
sheen.Parent = title

local mark = Instance.new("Frame")
mark.Name = "Mark"
mark.AnchorPoint = Vector2.new(0.5, 0.5)
mark.Position = UDim2.fromScale(0.5, 0.535)
mark.Size = UDim2.fromOffset(56, 3)
mark.BackgroundColor3 = AMBER
mark.BorderSizePixel = 0
mark.Parent = canvas

local tagline = label("Tagline", "Someone in this house is lying.", 19, SOFT, MONO)
tagline.Position = UDim2.fromScale(0.5, 0.585)
tagline.Size = UDim2.fromOffset(700, 26)

local status = label("Status", "OPENING THE CASE FILE", 13, MUTED, MONO)
status.Position = UDim2.fromScale(0.5, 0.685)
status.Size = UDim2.fromOffset(600, 20)

local track = Instance.new("Frame")
track.Name = "Track"
track.AnchorPoint = Vector2.new(0.5, 0.5)
track.Position = UDim2.fromScale(0.5, 0.725)
track.Size = UDim2.fromOffset(440, 4)
track.BackgroundColor3 = SUNK
track.BorderSizePixel = 0
track.Parent = canvas
local trackStroke = Instance.new("UIStroke")
trackStroke.Color = STROKE
trackStroke.Thickness = 1
trackStroke.Parent = track
local fill = Instance.new("Frame")
fill.Name = "Fill"
fill.Size = UDim2.fromScale(0, 1)
fill.BackgroundColor3 = AMBER
fill.BorderSizePixel = 0
fill.Parent = track

local version = label("Version", ("v%d"):format(game.PlaceVersion), 12, DIM, MONO)
version.AnchorPoint = Vector2.new(1, 1)
version.Position = UDim2.new(1, -20, 1, -16)
version.Size = UDim2.fromOffset(120, 18)
version.TextXAlignment = Enum.TextXAlignment.Right

-- On a phone the column is the same, only the type a little smaller
local function fit()
    local cam = workspace.CurrentCamera
    local narrow = cam ~= nil and cam.ViewportSize.X < 600
    titleFit.MaxTextSize = if narrow then 72 else 112
    tagline.TextSize = if narrow then 15 else 19
    track.Size = UDim2.fromOffset(if narrow then 260 else 440, 4)
end
fit()
local camera = workspace.CurrentCamera
if camera then
    camera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
end

gui.Parent = playerGui
local shownAt = os.clock()

---------------------------------------------------------------- Motion
local sweeping = true
task.spawn(function()
    while sweeping do
        sheen.Offset = Vector2.new(-1, 0)
        local sweep = TweenService:Create(
            sheen,
            TweenInfo.new(2.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
            { Offset = Vector2.new(1, 0) }
        )
        sweep:Play()
        sweep.Completed:Wait()
        task.wait(1.1)
    end
end)

---------------------------------------------------------------- Progress
-- The bar only ever moves forward, and eases into each new mark
local progress = 0
local function reach(fraction: number)
    progress = math.max(progress, math.clamp(fraction, 0, 1))
    TweenService:Create(
        fill,
        TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { Size = UDim2.fromScale(progress, 1) }
    ):Play()
end

local function step(text: string)
    status.Text = string.upper(text)
end

step("Opening the case file")
if not game:IsLoaded() then
    game.Loaded:Wait()
end
reach(0.2)

step("Reading the floor plans")
local Shared = ReplicatedStorage:WaitForChild("Shared", PATIENCE)
ReplicatedStorage:WaitForChild("Remotes", PATIENCE)
reach(0.4)

step("Dusting for prints")
-- The two faces the whole game is set in, and every sound cue, so the first
-- round does not stutter loading them
local assets: { Instance } = {}
for _, font in { DISPLAY, MONO } do
    local sample = Instance.new("TextLabel")
    sample.FontFace = font
    sample.Text = "A"
    table.insert(assets, sample)
end
if Shared then
    local ok, cues = pcall(require, Shared:WaitForChild("SoundCues", PATIENCE))
    if ok and type(cues) == "table" then
        for _, cue in cues :: { [string]: any } do
            if type(cue) == "table" and type(cue.soundId) == "string" and cue.soundId ~= "" then
                local sound = Instance.new("Sound")
                sound.SoundId = cue.soundId
                table.insert(assets, sound)
            end
        end
    end
end
local total, loaded = #assets, 0
ContentProvider:PreloadAsync(assets, function()
    loaded += 1
    reach(0.4 + 0.4 * loaded / math.max(total, 1))
end)
reach(0.8)

step("Calling the witnesses")
-- The profile is in once Rank is set; the HUD is up once HudController built it
local deadline = os.clock() + PATIENCE
while plr:GetAttribute("Rank") == nil and os.clock() < deadline do
    task.wait(0.1)
end
playerGui:WaitForChild("RoundHud", PATIENCE)
reach(1)
step("The case is open")

---------------------------------------------------------------- Exit
local remaining = MIN_SHOWN - (os.clock() - shownAt)
if remaining > 0 then
    task.wait(remaining)
end
task.wait(0.3) -- let the bar arrive
sweeping = false
local out = TweenService:Create(
    canvas,
    TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
    { GroupTransparency = 1 }
)
out:Play()
out.Completed:Wait()
gui:Destroy()
