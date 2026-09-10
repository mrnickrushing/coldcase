-- Creates every RemoteEvent in ReplicatedStorage.Remotes. Idempotent.
-- Bootstrap calls it on server start; it can also be run from the command bar:
--   require(game.ReplicatedStorage.Shared.RemoteSetup)()
local NAMES = {
    -- server -> client
    "RoundState",
    "RoleAssigned",
    "BodyDropped",
    "Clue",
    "RoundOver",
    "RoundReward",
    "EventFired",
    "DataChanged",
    "CrateResult",
    "TradeUpdate",
    "TradeComplete",
    "AliveChanged",
    "VoteTally",
    "PlayCue",
    "Notify",
    "AbilityState",
    "CosmeticChanged",
    "ShopResult",
    "Spectate",
    "RadioMessage",
    "EmotePlayed",
    -- client -> server (every one is rate-limited and re-validated)
    "RequestStab",
    "RequestThrow",
    "RequestShoot",
    "RequestExamine",
    "RequestPickup",
    "RequestCoin",
    "RequestVote",
    "RequestCrate",
    "RequestTrade",
    "HintSeen",
    "RequestRevive",
    "RequestDrag",
    "RequestCraft",
    "RequestEquip",
    "RequestBuy",
    "RequestReroll",
    "RequestRadio",
    "RequestEmote",
    "RequestReport",
    "RequestSpectate",
}

return function()
    local rs = game:GetService("ReplicatedStorage")
    local folder = rs:FindFirstChild("Remotes")
    local isNew = folder == nil
    if isNew then
        folder = Instance.new("Folder")
        folder.Name = "Remotes"
    end
    for _, n in NAMES do
        if not folder:FindFirstChild(n) then
            local ev = Instance.new("RemoteEvent")
            ev.Name = n
            ev.Parent = folder
        end
    end
    -- Parent last so clients receive the folder with every remote already in it
    if isNew then
        folder.Parent = rs
    end
    return folder
end
