-- Equipping, and the weapon a player carries into a round.
-- Cosmetic only — never touches lethality, speed or vision.
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local Catalog = require(game.ReplicatedStorage.Shared.Catalog)
local Theme = require(game.ReplicatedStorage.Shared.Theme)
local ItemCard = require(game.ReplicatedStorage.Shared.Build.ItemCard)
local Remotes = game.ReplicatedStorage.Remotes
local DataService = require(script.Parent.DataService)

local CosmeticService = {}

local SLOT_FOR_KIND = { Knife = "knife", Pistol = "gun", Effect = "effect", Pet = "pet" }
local DEFAULTS: { [string]: string } = { knife = "ash", gun = "ledger" }
local drawToken: { [Player]: number } = {}

local function owns(data, id: string): boolean
    if Catalog[id] and Catalog[id].starter then
        return true -- starters are owned by everyone and never enter the inventory
    end
    for _, item in data.inventory do
        if item.id == id then
            return true
        end
    end
    return false
end

-- `ref` is an inventory uid, or a starter item id
function CosmeticService:Equip(plr: Player, ref: string)
    local data = DataService:Get(plr)
    if not data then
        return
    end

    local id
    if Catalog[ref] and Catalog[ref].starter then
        id = ref
    else
        for _, item in data.inventory do
            if item.uid == ref then
                id = item.id
                break
            end
        end
    end
    local def = id and Catalog[id]
    local slot = def and SLOT_FOR_KIND[def.kind]
    if not slot then
        return
    end

    data.equipped[slot] = id
    Remotes.DataChanged:FireClient(plr, { equipped = data.equipped })
    -- Broadcast so other clients can swap the visible model once models exist
    Remotes.CosmeticChanged:FireAllClients(plr, slot, id)
end

-- After items leave an inventory (trade, craft), unequip anything no longer owned
function CosmeticService:Reconcile(plr: Player)
    local data = DataService:Get(plr)
    if not data then
        return
    end
    local changed = false
    for slot, id in data.equipped do
        if not owns(data, id) then
            data.equipped[slot] = DEFAULTS[slot]
            changed = true
        end
    end
    if changed then
        Remotes.DataChanged:FireClient(plr, { equipped = data.equipped })
    end
end

---------------------------------------------------------------- Weapons
local function weaponsOf(plr: Player, slot: string?): { Tool }
    local containers: { Instance } = {}
    if plr.Character then
        table.insert(containers, plr.Character)
    end
    local backpack = plr:FindFirstChildOfClass("Backpack")
    if backpack then
        table.insert(containers, backpack)
    end
    local out = {}
    for _, container in containers do
        for _, child in container:GetChildren() do
            local tag = child:GetAttribute("Weapon")
            if child:IsA("Tool") and tag ~= nil and (slot == nil or tag == slot) then
                table.insert(out, child)
            end
        end
    end
    return out
end

local function blockout(slot: string, rarity: string?): Tool
    local tool = Instance.new("Tool")
    local handle = Instance.new("Part")
    handle.Name = "Handle"
    handle.Size = if slot == "knife"
        then Vector3.new(0.25, 0.4, 2.2)
        else Vector3.new(0.4, 0.9, 1.6)
    handle.Color = (rarity and ItemCard.RARITY_COLOUR[rarity]) or Theme.MUTED
    handle.Material = Enum.Material.SmoothPlastic
    handle.Parent = tool
    return tool
end

-- The weapon for a round, carried hidden in the backpack. A knife held all
-- round would name the murderer to anyone who looks, so CombatService draws
-- it for a moment on each use instead. Uses the Tool at
-- ServerStorage.Cosmetics.<itemId> when there is one, then the generic
-- Cosmetics.knife / Cosmetics.gun with a rarity outline, else a tinted blockout.
function CosmeticService:GiveWeapon(plr: Player, slot: string)
    local backpack = plr:FindFirstChildOfClass("Backpack")
    if not (plr.Character and backpack) then
        return
    end
    self:ClearWeapons(plr)
    local data = DataService:Get(plr)
    local id: string = (data and data.equipped[slot]) or DEFAULTS[slot]
    local def = Catalog[id]
    local folder = ServerStorage:FindFirstChild("Cosmetics")
    local own = folder and folder:FindFirstChild(id)
    local generic = folder and folder:FindFirstChild(slot)
    local template = if own and own:IsA("Tool")
        then own
        elseif generic and generic:IsA("Tool") then generic
        else nil
    local tool = if template then template:Clone() else blockout(slot, def and def.rarity)
    if template == generic and def and def.rarity ~= "Common" then
        -- One model for every item in the slot; the rarity shows as an outline
        local outline = Instance.new("Highlight")
        outline.FillTransparency = 1
        outline.OutlineColor = ItemCard.RARITY_COLOUR[def.rarity] or Theme.MUTED
        outline.OutlineTransparency = 0.35
        outline.DepthMode = Enum.HighlightDepthMode.Occluded
        outline.Parent = tool
    end
    tool.Name = def and def.name or id
    tool.RequiresHandle = true
    tool.CanBeDropped = false
    tool.ManualActivationOnly = true
    tool:SetAttribute("Weapon", slot)
    for _, d in tool:GetDescendants() do
        if d:IsA("LuaSourceContainer") then
            d:Destroy() -- a weapon model never runs code
        elseif d:IsA("BasePart") then
            -- Never in the way of a stab, a shot or a raycast
            d.CanCollide = false
            d.CanTouch = false
            d.CanQuery = false
            d.Massless = true
        end
    end
    tool.Parent = backpack
end

function CosmeticService:DrawWeapon(plr: Player, slot: string, seconds: number)
    local char = plr.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local tool = weaponsOf(plr, slot)[1]
    if not (hum and tool and hum.Health > 0) then
        return
    end
    hum:EquipTool(tool)
    local token = (drawToken[plr] or 0) + 1
    drawToken[plr] = token
    task.delay(seconds, function()
        if drawToken[plr] == token and tool.Parent == char then
            hum:UnequipTools()
        end
    end)
end

function CosmeticService:ClearWeapons(plr: Player)
    for _, tool in weaponsOf(plr) do
        tool:Destroy()
    end
end

Players.PlayerRemoving:Connect(function(plr)
    drawToken[plr] = nil
end)

return CosmeticService
