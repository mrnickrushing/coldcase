-- Equipping. Cosmetic only — never touches lethality, speed or vision.
local Catalog = require(game.ReplicatedStorage.Shared.Catalog)
local Remotes = game.ReplicatedStorage.Remotes
local DataService = require(script.Parent.DataService)

local CosmeticService = {}

local SLOT_FOR_KIND = { Knife = "knife", Pistol = "gun", Effect = "effect", Pet = "pet" }
local DEFAULTS = { knife = "ash", gun = "ledger" }

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

return CosmeticService
