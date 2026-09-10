-- Asks for a coin when standing on a node. Sends a node id — never an amount.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Config = require(ReplicatedStorage:WaitForChild("Shared").Config)
local ClientState = require(script.Parent.Parent.ClientState)

local plr = Players.LocalPlayer
local asked: { [BasePart]: boolean } = {}
local CoinController = {}

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
        for _, node in CollectionService:GetTagged("CoinNode") do
            if node:IsA("BasePart") and not asked[node] and node:IsDescendantOf(workspace) then
                if (node.Position - here).Magnitude <= Config.COIN_PICKUP_RANGE then
                    asked[node] = true
                    Remotes.RequestCoin:FireServer(node:GetAttribute("NodeId"))
                end
            end
        end
    end
end)

CollectionService:GetInstanceRemovedSignal("CoinNode"):Connect(function(node)
    asked[node] = nil
end)

return CoinController
