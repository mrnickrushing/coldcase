-- Coin pickups (Handbook §06 · Coin injection). The client only names a node
-- it believes it is standing on; the server owns the node list, the one-time
-- taken flag, the range check and the amount.
local Config = require(game.ReplicatedStorage.Shared.Config)
local EconomyService = require(script.Parent.EconomyService)
local CombatFx = require(game.ReplicatedStorage.Shared.CombatFx)

local CoinService = {}
local nodes: { [number]: BasePart } = {}
local armed = false
local round: any = nil -- RoundService, handed over by BindRound

function CoinService:BindRound(roundService)
    round = roundService
end

function CoinService:Arm(roundFolder: Instance)
    nodes = {}
    local nextId = 1
    for _, part in roundFolder:GetDescendants() do
        if part:IsA("BasePart") and part:HasTag("CoinNode") then
            part:SetAttribute("NodeId", nextId)
            nodes[nextId] = part
            nextId += 1
        end
    end
    armed = true
end

function CoinService:Disarm()
    armed = false
    for _, part in nodes do
        part:Destroy()
    end
    nodes = {}
end

function CoinService:RequestCoin(plr: Player, nodeId: any)
    if not armed or type(nodeId) ~= "number" then
        return
    end
    local node = nodes[nodeId]
    if not node then
        return -- unknown, or already taken
    end
    local char = plr.Character
    if not (char and round:IsAlive(plr)) then
        return
    end
    local reach = Config.COIN_PICKUP_RANGE + Config.PING_ALLOWANCE
    if (char:GetPivot().Position - node.Position).Magnitude > reach then
        return
    end

    nodes[nodeId] = nil -- one-time flag, set before anything can yield
    CombatFx.Pickup(node.Position)
    node:Destroy()
    EconomyService:Grant(plr, Config.COIN_PICKUP, 0, "pickup")
end

return CoinService
