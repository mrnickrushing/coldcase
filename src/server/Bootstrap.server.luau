-- ServerScriptService/Bootstrap — the only server entry point.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

-- Remotes, maps and lighting must exist before any service is required
require(ReplicatedStorage.Shared.RemoteSetup)()
require(ServerStorage.Build.BuildAssets)() -- models first: BuildMaps dresses maps with them
require(ServerStorage.Build.BuildMaps)()
require(ServerStorage.Build.BuildLighting)()
require(ServerStorage.Build.BuildLobby)()

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
local SocialService = require(Services.SocialService)
local SpectatorService = require(Services.SpectatorService)
local SnitchService = require(Services.SnitchService)
require(Services.LeaderboardService) -- starts the global-board refresh loop
require(Services.PlayerPolicy) -- regional policy for paid random items and trading
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
    if typeof(target) ~= "Instance" then
        return
    end
    if target:IsA("Player") then
        CombatService:RequestStab(plr, target)
    elseif target:IsA("Model") then
        -- NPCs are targeted by their character model
        local bot = RoundService:BotFromCharacter(target)
        if bot then
            CombatService:RequestStab(plr, bot)
        end
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
    -- Note only a vote the round accepted: that way the map name reaching
    -- analytics is one of Config.MAPS, never a string the client chose.
    if type(mapName) == "string" and RoundService:CastVote(plr, mapName) then
        OnboardingService:NoteVote(plr, mapName)
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

RemoteGuard.Connect("RequestRadio", function(plr, message)
    if type(message) == "string" then
        SocialService:Radio(plr, message)
    end
end)

RemoteGuard.Connect("RequestEmote", function(plr, emoteId)
    if type(emoteId) == "string" then
        SocialService:Emote(plr, emoteId)
    end
end)

RemoteGuard.Connect("RequestReport", function(plr, target, reason)
    if typeof(target) == "Instance" and target:IsA("Player") and type(reason) == "string" then
        SocialService:Report(plr, target, reason)
    end
end)

RemoteGuard.Connect("RequestSpectate", function(plr)
    SpectatorService:Send(plr, RoundService:AliveNames())
end)

RemoteGuard.Connect("RequestLobbyMode", function(plr, mode)
    if mode == "wait" or mode == "play" then
        DataService:SetWaitForPlayers(plr, mode == "wait")
    end
end)

RemoteGuard.Connect("RequestExpose", function(plr)
    SnitchService:RequestExpose(plr)
end)

require(Services.BotService):Prepare() -- builds the NPC rig before the first round
RoundService:Start()
-- The place version says which publish this server is running, so a fix that
-- was merged but never published can be told apart from one that did not work.
print(("[ColdCase] server up · place version %d"):format(game.PlaceVersion))
