--!strict
-- StarterPlayerScripts/Controllers/PedestalController
-- Renders the knife a player has featured on a lobby pedestal: it hovers above
-- the stand, slowly spinning, with an owner + item nameplate. Driven entirely by
-- the pedestal's replicated attributes (Item / OwnerName), set by PedestalService.
-- Models come from the replicated ReplicatedStorage.PreviewModels; chroma blades
-- cycle their hue. This is the fixed-stand cousin of ShowcaseController.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalog = require(Shared.Catalog)
local Theme = require(Shared.Theme)
local ItemCard = require(Shared.Build.ItemCard)

type Display = { id: string, model: Model, chroma: boolean, platform: BasePart }
local displays: { [Model]: Display } = {}

local folder = Instance.new("Folder")
folder.Name = "PedestalDisplays"
folder.Parent = workspace

local function clear(ped: Model)
    local d = displays[ped]
    if d then
        d.model:Destroy()
        displays[ped] = nil
    end
end

local function build(ped: Model)
    clear(ped)
    local id = ped:GetAttribute("Item")
    local def = type(id) == "string" and id ~= "" and Catalog[id]
    local platform = ped.PrimaryPart
    if not (def and def.kind == "Knife" and platform) then
        return
    end
    local previews = ReplicatedStorage:FindFirstChild("PreviewModels")
    local template = previews and previews:FindFirstChild(id)
    if not (template and template:IsA("Model")) then
        return
    end
    local model = template:Clone()
    for _, part in model:GetDescendants() do
        if part:IsA("BasePart") then
            part.Anchored = true
            part.CanCollide = false
            part.CanQuery = false
            part.CanTouch = false
            part.CastShadow = false
        end
    end
    pcall(function()
        model:ScaleTo(0.85)
    end)
    local anchor = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
    if anchor then
        local tag = Instance.new("BillboardGui")
        tag.Name = "Plate"
        tag.Size = UDim2.fromOffset(190, 24)
        tag.StudsOffset = Vector3.new(0, 2, 0)
        tag.AlwaysOnTop = true
        tag.MaxDistance = 60
        tag.LightInfluence = 0
        local label = Instance.new("TextLabel")
        label.Size = UDim2.fromScale(1, 1)
        label.BackgroundTransparency = 1
        label.FontFace = Theme.DISPLAY
        label.TextSize = 14
        label.Text = ("%s · %s"):format(
            ped:GetAttribute("OwnerName") or "",
            string.upper(def.name)
        )
        label.TextColor3 = ItemCard.RARITY_COLOUR[def.rarity] or Theme.INK
        label.TextStrokeTransparency = 0.5
        label.Parent = tag
        tag.Adornee = anchor
        tag.Parent = anchor
    end
    model.Parent = folder
    displays[ped] =
        { id = id :: string, model = model, chroma = def.chroma == true, platform = platform }
end

local function watch(ped: Model)
    ped:GetAttributeChangedSignal("Item"):Connect(function()
        build(ped)
    end)
    build(ped)
end
for _, ped in CollectionService:GetTagged("Pedestal") do
    watch(ped)
end
CollectionService:GetInstanceAddedSignal("Pedestal"):Connect(watch)
CollectionService:GetInstanceRemovedSignal("Pedestal"):Connect(clear)

RunService.RenderStepped:Connect(function()
    local t = os.clock()
    local chromaColour = Color3.fromHSV((t * 0.25) % 1, 0.85, 1)
    for _, d in displays do
        local pos = d.platform.Position + Vector3.new(0, 1.7, 0)
        d.model:PivotTo(
            CFrame.new(pos) * CFrame.Angles(0, t * 1.1, 0) * CFrame.Angles(math.rad(15), 0, 0)
        )
        if d.chroma then
            for _, part in d.model:GetDescendants() do
                if part:IsA("BasePart") then
                    part.Color = chromaColour
                end
            end
        end
    end
end)

return {}
