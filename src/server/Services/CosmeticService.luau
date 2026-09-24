-- Equipping, and the weapon a player carries into a round.
-- Cosmetic only — never touches lethality, speed or vision.
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local Catalog = require(game.ReplicatedStorage.Shared.Catalog)
local Shop = require(game.ReplicatedStorage.Shared.Shop)
local Theme = require(game.ReplicatedStorage.Shared.Theme)
local ItemCard = require(game.ReplicatedStorage.Shared.Build.ItemCard)
local CosmeticFx = require(game.ReplicatedStorage.Shared.CosmeticFx)
local Remotes = game.ReplicatedStorage.Remotes
local DataService = require(script.Parent.DataService)
local Participant = require(script.Parent.Participant)

local CosmeticService = {}

local DEFAULTS: { [string]: string } = { knife = "ash", gun = "ledger" }
local drawToken: { [Player]: number } = {}

-- Roblox's own public tool animations (no upload). A knife use plays the lunge
-- so the arm thrusts on a stab or throw; if the id is ever unavailable it just
-- no-ops and the weapon still flashes as before. Gun recoil is the camera kick.
local LUNGE_ANIM = {
    [Enum.HumanoidRigType.R15] = "rbxassetid://522638767",
    [Enum.HumanoidRigType.R6] = "rbxassetid://129967478",
}

local function playSwing(hum: Humanoid)
    local animator = hum:FindFirstChildOfClass("Animator")
    local id = animator and LUNGE_ANIM[hum.RigType]
    if not (animator and id) then
        return
    end
    local anim = Instance.new("Animation")
    anim.AnimationId = id
    local ok, track = pcall(function()
        return animator:LoadAnimation(anim)
    end)
    anim:Destroy()
    if ok and track then
        track.Priority = Enum.AnimationPriority.Action
        track:Play(0.1)
        task.delay(track.Length > 0 and track.Length or 1, function()
            track:Stop(0.1)
            track:Destroy()
        end)
    end
end

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
    local slot = def and Shop.SLOT_FOR_KIND[def.kind]
    if not slot then
        return
    end

    data.equipped[slot] = id
    Remotes.DataChanged:FireClient(plr, { equipped = data.equipped })
    if slot == "effect" or slot == "pet" then
        self:ApplyWorn(plr)
    end
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
        self:ApplyWorn(plr)
    end
end

-- What a player wears outside the weapon slots: the Effect aura at the feet
-- (replicates to everyone) and the Pet id as a Player attribute, which each
-- client's PetController draws locally
function CosmeticService:ApplyWorn(plr: Player)
    local data = DataService:Get(plr)
    if not data then
        return
    end
    plr:SetAttribute("Pet", data.equipped.pet)
    local root = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
    if not root then
        return
    end
    local old = root:FindFirstChild("CosmeticAura")
    if old then
        old:Destroy()
    end
    local look = data.equipped.effect and CosmeticFx.AURA[data.equipped.effect]
    if look then
        local attachment = Instance.new("Attachment")
        attachment.Name = "CosmeticAura"
        attachment.Position = Vector3.new(0, -2.8, 0)
        CosmeticFx.Emitter(look).Parent = attachment
        attachment.Parent = root
    end
end

-- The effect rolled onto the equipped knife, if any copy of it has one
-- Top-tier knives carry a built-in blade effect so a Legendary or Godly always
-- looks the part, even before the owner spends a re-roll. A re-rolled effect on
-- the item still overrides it.
local SIGNATURE_EFFECT: { [string]: string } = {
    cinder = "ember",
    coldsnap = "frost",
    verdict = "gold",
}
local RARITY_EFFECT: { [string]: string } = {
    Legendary = "gold",
    Godly = "gold",
}
local function knifeEffect(data, id: string): string?
    for _, item in data.inventory do
        if item.id == id and item.effect and item.effect ~= "none" then
            return item.effect
        end
    end
    local sig = SIGNATURE_EFFECT[id]
    if sig then
        return sig
    end
    local def = Catalog[id]
    return def and RARITY_EFFECT[def.rarity] or nil
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

-- How strongly a drawn weapon glows by rarity: outline transparency, and a
-- fill transparency (1 = no fill) that lets the top tiers shine.
local GLOW: { [string]: { outline: number, fill: number } } = {
    Uncommon = { outline = 0.5, fill = 1 },
    Rare = { outline = 0.35, fill = 1 },
    Legendary = { outline = 0.2, fill = 0.82 },
    Godly = { outline = 0.08, fill = 0.7 },
}

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
    -- A rarity glow so a drawn weapon reads as rare in the moment it appears:
    -- a coloured outline for Uncommon and up, and a faint tinted fill that
    -- makes a Legendary or Godly blade glow. Also stands in for the mesh when
    -- one model serves the whole slot (a generic fallback or a blockout).
    local glow = def and GLOW[def.rarity]
    if glow then
        local c = ItemCard.RARITY_COLOUR[def.rarity] or Theme.MUTED
        local hl = Instance.new("Highlight")
        hl.OutlineColor = c
        hl.OutlineTransparency = glow.outline
        hl.FillColor = c
        hl.FillTransparency = glow.fill
        hl.DepthMode = Enum.HighlightDepthMode.Occluded
        hl.Parent = tool
    end
    tool.Name = def and def.name or id
    tool.RequiresHandle = true
    tool.CanBeDropped = false
    tool.ManualActivationOnly = true
    tool:SetAttribute("Weapon", slot)
    local effect = slot == "knife" and data and knifeEffect(data, id)
    local look = effect and CosmeticFx.KNIFE[effect]
    local handle = tool:FindFirstChild("Handle")
    if look and handle then
        CosmeticFx.Emitter(look).Parent = handle
    end
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

-- NPCs have no Backpack and cannot equip a Tool, so they would kill with empty
-- hands: no knife to witness, no tell to catch them by. They get the same
-- weapon model welded into the hand for the same moment a player shows one.
local function flashForBot(bot, slot: string, seconds: number)
    local char = bot.Character
    local hand = char and (char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm"))
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not (hand and hum and hum.Health > 0) then
        return
    end
    local old = char:FindFirstChild("DrawnWeapon")
    if old then
        old:Destroy()
    end
    local folder = ServerStorage:FindFirstChild("Cosmetics")
    local generic = folder and folder:FindFirstChild(slot)
    local handle: BasePart?
    if generic and generic:IsA("Tool") and generic:FindFirstChild("Handle") then
        handle = (generic.Handle :: BasePart):Clone()
    else
        handle = blockout(slot, nil):FindFirstChild("Handle") :: BasePart
    end
    if not handle then
        return
    end
    handle.Name = "DrawnWeapon"
    handle.CanCollide = false
    handle.CanTouch = false
    handle.CanQuery = false
    handle.Massless = true
    handle.CFrame = hand.CFrame * CFrame.new(0, -0.8, 0) * CFrame.Angles(math.rad(-90), 0, 0)
    local weld = Instance.new("WeldConstraint")
    weld.Part0 = hand
    weld.Part1 = handle
    weld.Parent = handle
    handle.Parent = char
    if slot == "knife" then
        playSwing(hum)
    end
    task.delay(seconds, function()
        if handle.Parent == char then
            handle:Destroy()
        end
    end)
end

function CosmeticService:DrawWeapon(plr: Player, slot: string, seconds: number)
    if Participant.IsBot(plr) then
        flashForBot(plr, slot, seconds)
        return
    end
    local char = plr.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local tool = weaponsOf(plr, slot)[1]
    if not (hum and tool and hum.Health > 0) then
        return
    end
    hum:EquipTool(tool)
    if slot == "knife" then
        playSwing(hum)
    end
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

DataService.Loaded.Event:Connect(function(plr: Player)
    CosmeticService:ApplyWorn(plr)
    plr.CharacterAdded:Connect(function()
        task.defer(CosmeticService.ApplyWorn, CosmeticService, plr)
    end)
end)

Players.PlayerRemoving:Connect(function(plr)
    drawToken[plr] = nil
end)

return CosmeticService
