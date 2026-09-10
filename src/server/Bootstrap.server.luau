-- ServerScriptService/Bootstrap — the only server entry point.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

-- Remotes and grey-box maps must exist before any service is required
require(ReplicatedStorage.Shared.RemoteSetup)()
require(ServerStorage.Build.BuildMaps)()

local Services = script.Parent.Services
local RemoteGuard = require(Services.RemoteGuard)
local DataService = require(Services.DataService)
local RoundService = require(Services.RoundService)
local CombatService = require(Services.CombatService)
local EvidenceService = require(Services.EvidenceService)
local EconomyService = require(Services.EconomyService)
local CoinService = require(Services.CoinService)
local TradeService = require(Services.TradeService)
local OnboardingService = require(Services.OnboardingService)
local AbilityService = require(Services.AbilityService)
local CosmeticService = require(Services.CosmeticService)
local ShopService = require(Services.ShopService)
local LiveOpsClock = require(Services.LiveOpsClock)
require(Services.MonetizationService) -- installs ProcessReceipt

-- Player lifecycle
Players.PlayerAdded:Connect(function(plr)
    DataService:Load(plr)
end)
for _, plr in Players:GetPlayers() do
    task.spawn(DataService.Load, DataService, plr)
end

-- Public live-ops state: seasonal crate, countdown, trading unlock
LiveOpsClock.Publish()
ServerStorage:GetAttributeChangedSignal("LiveOpsDay"):Connect(LiveOpsClock.Publish)
task.spawn(function()
    while true do
        task.wait(300)
        LiveOpsClock.Publish()
    end
end)

-- Client -> server entry points. Every one is rate-limited by RemoteGuard,
-- type-checked here, and re-validated inside the service. Handlers forward
-- only the arguments they expect, never `...`.
RemoteGuard.Connect("RequestStab", function(plr, target)
    if typeof(target) == "Instance" and target:IsA("Player") then
        CombatService:RequestStab(plr, target)
    end
end)

RemoteGuard.Connect("RequestThrow", function(plr, aimPoint)
    if RemoteGuard.IsFiniteVector(aimPoint) then
        CombatService:RequestThrow(plr, aimPoint)
    end
end)

RemoteGuard.Connect("RequestShoot", function(plr, aimPoint)
    if RemoteGuard.IsFiniteVector(aimPoint) then
        CombatService:RequestShoot(plr, aimPoint)
    end
end)

RemoteGuard.Connect("RequestExamine", function(plr, model)
    if typeof(model) == "Instance" then
        EvidenceService:Examine(plr, model)
    end
end)

RemoteGuard.Connect("RequestPickup", function(plr)
    CombatService:RequestPickup(plr)
end)

RemoteGuard.Connect("RequestCoin", function(plr, nodeId)
    CoinService:RequestCoin(plr, nodeId)
end)

RemoteGuard.Connect("RequestRevive", function(plr, model)
    if typeof(model) == "Instance" then
        AbilityService:RequestRevive(plr, model)
    end
end)

RemoteGuard.Connect("RequestDrag", function(plr, model, stop)
    if stop == true then
        AbilityService:StopDrag(plr)
    elseif typeof(model) == "Instance" then
        AbilityService:StartDrag(plr, model)
    end
end)

RemoteGuard.Connect("RequestVote", function(plr, mapName)
    if type(mapName) == "string" then
        RoundService:CastVote(plr, mapName)
        OnboardingService:NoteVote(plr)
    end
end)

RemoteGuard.Connect("RequestCrate", function(plr, crateId)
    EconomyService:OpenCrate(plr, crateId)
end)

RemoteGuard.Connect("RequestCraft", function(plr, itemId)
    if type(itemId) == "string" then
        EconomyService:Craft(plr, itemId)
    end
end)

RemoteGuard.Connect("RequestEquip", function(plr, ref)
    if type(ref) == "string" then
        CosmeticService:Equip(plr, ref)
    end
end)

RemoteGuard.Connect("RequestBuy", function(plr, id)
    if type(id) == "string" then
        ShopService:Buy(plr, id)
    end
end)

RemoteGuard.Connect("RequestReroll", function(plr, uid)
    if type(uid) == "string" then
        ShopService:RerollEffect(plr, uid)
    end
end)

RemoteGuard.Connect("RequestTrade", function(plr, action, payload)
    TradeService:Handle(plr, action, payload)
end)

RemoteGuard.Connect("HintSeen", function(plr, hintId)
    OnboardingService:MarkHintSeen(plr, hintId)
end)

RoundService:Start()
print("[ColdCase] server up")
