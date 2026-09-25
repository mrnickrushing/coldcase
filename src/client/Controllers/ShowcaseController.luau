--!strict
-- StarterPlayerScripts/Controllers/ShowcaseController
-- The lobby hangout: every player's equipped knife floats and slowly spins
-- above their head with a rarity-coloured nameplate, so you can walk the lobby
-- and see what everyone is carrying. Drawn locally from each player's public
-- "Knife" attribute (set by CosmeticService); models come from the already
-- replicated ReplicatedStorage.PreviewModels. Chroma blades cycle their hue.
-- Only ever shown in the lobby (INTERMISSION); during a round the real weapon
-- is in hand and this is hidden.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalog = require(Shared.Catalog)
local Theme = require(Shared.Theme)
local ItemCard = require(Shared.Build.ItemCard)

local ShowcaseController = {}
type Show = { id: string, model: Model, chroma: boolean }
local shows: { [Player]: Show } = {}

local folder = Instance.new("Folder")
folder.Name = "KnifeShowcase"
folder.Parent = workspace

local function inLobby(): boolean
    return ReplicatedStorage:GetAttribute("RoundState") == "INTERMISSION"
end

local function build(id: string, def): Model?
    local previews = ReplicatedStorage:FindFirstChild("PreviewModels")
    local template = previews and previews:FindFirstChild(id)
    if not (template and template:IsA("Model")) then
        return nil
    end
    local model = template:Clone()
    for _, d in model:GetDescendants() do
        if d:IsA("BasePart") then
            d.Anchored = true
            d.CanCollide = false
            d.CanQuery = false
            d.CanTouch = false
            d.CastShadow = false
        end
    end
    local ok = pcall(function()
        model:ScaleTo(0.8)
    end)
    if not ok then
        -- older engines: leave at natural size
    end
    -- A rarity-coloured nameplate above the blade.
    local anchor = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
    if anchor then
        local tag = Instance.new("BillboardGui")
        tag.Name = "Plate"
        tag.Size = UDim2.fromOffset(150, 24)
        tag.StudsOffset = Vector3.new(0, 2, 0)
        tag.AlwaysOnTop = true
        tag.MaxDistance = 60
        tag.LightInfluence = 0
        local label = Instance.new("TextLabel")
        label.Size = UDim2.fromScale(1, 1)
        label.BackgroundTransparency = 1
        label.FontFace = Theme.DISPLAY
        label.TextSize = 15
        label.Text = string.upper(def.name)
        label.TextColor3 = ItemCard.RARITY_COLOUR[def.rarity] or Theme.INK
        label.TextStrokeTransparency = 0.5
        label.Parent = tag
        tag.Adornee = anchor
        tag.Parent = anchor
    end
    return model
end

local function clear(plr: Player)
    local show = shows[plr]
    if show then
        show.model:Destroy()
        shows[plr] = nil
    end
end

local function refresh(plr: Player)
    local id = plr:GetAttribute("Knife")
    local current = shows[plr]
    if current and current.id == id and inLobby() then
        return
    end
    clear(plr)
    if not inLobby() then
        return
    end
    local def = type(id) == "string" and Catalog[id]
    if not (def and def.kind == "Knife") then
        return
    end
    local model = build(id :: string, def)
    if model then
        model.Name = plr.Name
        model.Parent = folder
        shows[plr] = { id = id :: string, model = model, chroma = def.chroma == true }
    end
end

local function watch(plr: Player)
    plr:GetAttributeChangedSignal("Knife"):Connect(function()
        refresh(plr)
    end)
    refresh(plr)
end
Players.PlayerAdded:Connect(watch)
for _, plr in Players:GetPlayers() do
    watch(plr)
end
Players.PlayerRemoving:Connect(clear)

ReplicatedStorage:GetAttributeChangedSignal("RoundState"):Connect(function()
    if inLobby() then
        for _, plr in Players:GetPlayers() do
            refresh(plr)
        end
    else
        for plr in shows do
            clear(plr)
        end
    end
end)

-- Float above the head, spinning about its own axis (independent of which way
-- the owner faces), with a small showpiece tilt.
RunService.RenderStepped:Connect(function()
    if not inLobby() then
        return
    end
    local t = os.clock()
    local chromaColour = Color3.fromHSV((t * 0.25) % 1, 0.85, 1)
    for plr, show in shows do
        local char = plr.Character
        local head = char and char:FindFirstChild("Head")
        if head and head:IsA("BasePart") then
            local pos = head.Position + Vector3.new(0, 2.6, 0)
            show.model:PivotTo(
                CFrame.new(pos) * CFrame.Angles(0, t * 1.4, 0) * CFrame.Angles(math.rad(20), 0, 0)
            )
            show.model.Parent = folder
            if show.chroma then
                for _, d in show.model:GetDescendants() do
                    if d:IsA("BasePart") then
                        d.Color = chromaColour
                    end
                end
            end
        else
            show.model.Parent = nil -- hidden while the owner has no character
        end
    end
end)

return ShowcaseController
