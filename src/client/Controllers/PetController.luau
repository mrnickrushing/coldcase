-- StarterPlayerScripts/Controllers/PetController
-- Draws every player's pet locally from their "Pet" attribute (set by
-- CosmeticService). Pets follow at the shoulder with a slow bob and never touch
-- physics or raycasts. Models come from ReplicatedStorage.PetModels.<itemId>
-- in the place file; without one, a small rarity-coloured orb stands in.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalog = require(Shared.Catalog)
local ItemCard = require(Shared.Build.ItemCard)

local PetController = {}
local pets: { [Player]: { id: string, model: Model, placed: boolean } } = {}
local dark = false

local folder = Instance.new("Folder")
folder.Name = "Pets"
folder.Parent = workspace

local function build(id: string): Model
    local templates = ReplicatedStorage:FindFirstChild("PetModels")
    local template = templates and templates:FindFirstChild(id)
    local model: Model
    if template and template:IsA("Model") then
        model = template:Clone()
    else
        model = Instance.new("Model")
        local orb = Instance.new("Part")
        orb.Shape = Enum.PartType.Ball
        orb.Size = Vector3.new(0.8, 0.8, 0.8)
        local def = Catalog[id]
        orb.Color = (def and ItemCard.RARITY_COLOUR[def.rarity]) or Color3.new(1, 1, 1)
        orb.Material = Enum.Material.SmoothPlastic
        orb.Parent = model
        model.PrimaryPart = orb
    end
    for _, d in model:GetDescendants() do
        if d:IsA("LuaSourceContainer") then
            d:Destroy()
        elseif d:IsA("BasePart") then
            d.Anchored = true
            d.CanCollide = false
            d.CanQuery = false
            d.CanTouch = false
            d.CastShadow = false
        elseif d:IsA("Light") then
            d:SetAttribute("BaseBrightness", d.Brightness)
        end
    end
    return model
end

-- Nightwatch "dims during Lights Out instead of helping"
local function applyDark()
    for _, pet in pets do
        for _, d in pet.model:GetDescendants() do
            if d:IsA("Light") then
                local base = d:GetAttribute("BaseBrightness") or d.Brightness
                d.Brightness = dark and base * 0.1 or base
            end
        end
    end
end

-- Where a pet sits for its owner, or nil while the owner is dead or absent
local function goalFor(plr: Player, t: number): CFrame?
    local char = plr.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not (root and root:IsA("BasePart") and hum and hum.Health > 0) then
        return nil
    end
    local bob = math.sin(t * 2 + plr.UserId % 7) * 0.25
    return root.CFrame * CFrame.new(2.2, 1.2 + bob, 1.4)
end

local function refresh(plr: Player)
    local id = plr:GetAttribute("Pet")
    local current = pets[plr]
    if current and current.id == id then
        return
    end
    if current then
        current.model:Destroy()
        pets[plr] = nil
    end
    local def = type(id) == "string" and Catalog[id]
    if def and def.kind == "Pet" then
        local model = build(id)
        model.Name = plr.Name
        -- Placed now rather than on the next rendered frame
        local goal = goalFor(plr, os.clock())
        if goal then
            model:PivotTo(goal)
            model.Parent = folder
        end
        pets[plr] = { id = id, model = model, placed = goal ~= nil }
        applyDark()
    end
end

local function watch(plr: Player)
    plr:GetAttributeChangedSignal("Pet"):Connect(function()
        refresh(plr)
    end)
    refresh(plr)
end
Players.PlayerAdded:Connect(watch)
for _, plr in Players:GetPlayers() do
    watch(plr)
end
Players.PlayerRemoving:Connect(function(plr)
    local pet = pets[plr]
    if pet then
        pet.model:Destroy()
        pets[plr] = nil
    end
end)

Remotes.EventFired.OnClientEvent:Connect(function(id: string)
    if id == "LIGHTS_OUT" or id == "POWER_SURGE" then
        dark = true
        applyDark()
    elseif id == "CLEAR" then
        dark = false
        applyDark()
    end
end)
ReplicatedStorage:GetAttributeChangedSignal("RoundState"):Connect(function()
    if dark and ReplicatedStorage:GetAttribute("RoundState") ~= "ACTIVE" then
        dark = false
        applyDark()
    end
end)

RunService.RenderStepped:Connect(function(dt)
    local t = os.clock()
    for plr, pet in pets do
        local goal = goalFor(plr, t)
        if not goal then
            -- Hidden with a dead owner, so a pet never marks a body
            pet.model.Parent = nil
            pet.placed = false
            continue
        end
        if pet.placed then
            pet.model:PivotTo(pet.model:GetPivot():Lerp(goal, math.min(1, dt * 8)))
        else
            pet.model:PivotTo(goal)
            pet.placed = true
        end
        pet.model.Parent = folder
    end
end)

return PetController
