-- Lobby showcase pedestals: hold the prompt to feature your equipped knife on a
-- stand, hold it again to take it down. One pedestal per player. The state lives
-- in replicated attributes on each pedestal (Owner, OwnerName, Item) so clients
-- render the featured knife straight from them - no remote needed.
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local PedestalService = {}
local ownedBy: { [Player]: Model } = {}

local function release(ped: Model)
    ped:SetAttribute("Owner", 0)
    ped:SetAttribute("OwnerName", "")
    ped:SetAttribute("Item", "")
end

local function claim(ped: Model, plr: Player)
    local knife = plr:GetAttribute("Knife")
    if type(knife) ~= "string" or knife == "" then
        return
    end
    local prev = ownedBy[plr]
    if prev and prev ~= ped then
        release(prev)
    end
    ownedBy[plr] = ped
    ped:SetAttribute("Owner", plr.UserId)
    ped:SetAttribute("OwnerName", plr.DisplayName)
    ped:SetAttribute("Item", knife)
end

local function onTrigger(ped: Model, plr: Player)
    local owner = ped:GetAttribute("Owner") or 0
    if owner == plr.UserId then
        release(ped)
        ownedBy[plr] = nil
    elseif owner == 0 then
        claim(ped, plr)
    end
    -- occupied by someone else: leave it be
end

local function wire(ped: Model)
    release(ped) -- start empty every server
    for _, d in ped:GetDescendants() do
        if d:IsA("ProximityPrompt") then
            d.Triggered:Connect(function(plr)
                onTrigger(ped, plr)
            end)
        end
    end
end

for _, ped in CollectionService:GetTagged("Pedestal") do
    wire(ped)
end
CollectionService:GetInstanceAddedSignal("Pedestal"):Connect(wire)

-- Keep a featured knife in step with the owner's equipped knife.
local function watch(plr: Player)
    plr:GetAttributeChangedSignal("Knife"):Connect(function()
        local ped = ownedBy[plr]
        local knife = plr:GetAttribute("Knife")
        if ped and type(knife) == "string" and knife ~= "" then
            ped:SetAttribute("Item", knife)
        end
    end)
end
Players.PlayerAdded:Connect(watch)
for _, plr in Players:GetPlayers() do
    watch(plr)
end
Players.PlayerRemoving:Connect(function(plr)
    local ped = ownedBy[plr]
    if ped then
        release(ped)
        ownedBy[plr] = nil
    end
end)

return PedestalService
