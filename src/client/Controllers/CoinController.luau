--!strict
-- Asks for a coin when standing on a node. Sends a node id — never an amount.
-- The server measures against its own copy of the character, which trails
-- the client by the player's ping, so an ask can be refused while the client
-- already stands on the coin. Keep asking, at a polite interval, until the
-- node is gone or the player walks away.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Config = require(ReplicatedStorage:WaitForChild("Shared").Config)
local ClientState = require(script.Parent.Parent.ClientState)

local plr = Players.LocalPlayer
local lastAsked: { [BasePart]: number } = {}
local CoinController = {}
local RETRY_INTERVAL = 0.5

task.spawn(function()
    while true do
        task.wait(0.15)
        if ClientState.GetRoundState() ~= "ACTIVE" or not ClientState.role then
            continue
        end
        local char = plr.Character
        if not char then
            continue
        end
        local here = char:GetPivot().Position
        local now = os.clock()
        for _, node in CollectionService:GetTagged("CoinNode") do
            if not (node:IsA("BasePart") and node:IsDescendantOf(workspace)) then
                continue
            end
            if (node.Position - here).Magnitude > Config.COIN_PICKUP_RANGE then
                continue
            end
            if now - (lastAsked[node] or 0) >= RETRY_INTERVAL then
                lastAsked[node] = now
                Remotes.RequestCoin:FireServer(node:GetAttribute("NodeId"))
            end
        end
    end
end)

CollectionService:GetInstanceRemovedSignal("CoinNode"):Connect(function(node)
    lastAsked[node] = nil
end)

-- Spin and bob every coin node, purely local. The disc turns about the vertical
-- axis so it shows a face then its edge, and rides a slow sine so it reads as a
-- floating pickup, not a decal. Anchored server parts, so this stays on the
-- client and never touches the server's static pickup position.
local baseY: { [BasePart]: number } = {}
RunService.Heartbeat:Connect(function()
    local t = os.clock()
    for _, node in CollectionService:GetTagged("CoinNode") do
        if node:IsA("BasePart") and node:IsDescendantOf(workspace) then
            local by = baseY[node]
            if not by then
                by = node.Position.Y
                baseY[node] = by
            end
            local bob = math.sin(t * 2.2 + node.Position.X * 0.1) * 0.4
            node.CFrame = CFrame.new(node.Position.X, by + bob, node.Position.Z)
                * CFrame.Angles(0, t * 2.4, 0)
        end
    end
end)

CollectionService:GetInstanceRemovedSignal("CoinNode"):Connect(function(node)
    baseY[node :: BasePart] = nil
end)

return CoinController
