--!strict
-- StarterPlayerScripts/Controllers/NoticeController
-- Ghost hints (Handbook §02) and short toasts, drawn above every menu.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Catalog = require(Shared.Catalog)
local BuildNotices = require(Shared.Build.BuildNotices)
local ClientState = require(script.Parent.Parent.ClientState)

local plr = Players.LocalPlayer
local playerGui = plr:WaitForChild("PlayerGui")
local gui = playerGui:FindFirstChild("NoticeHud") or BuildNotices(playerGui)
local NoticeController = {}
local FADE = TweenInfo.new(0.35)

---------------------------------------------------------------- Toasts
local queue: { string } = {}
local toasting = false

local function toast(text: string)
    table.insert(queue, text)
    if toasting then
        return
    end
    toasting = true
    task.spawn(function()
        while #queue > 0 do
            gui.Toast.Text = table.remove(queue, 1)
            TweenService
                :Create(gui.Toast, FADE, { TextTransparency = 0, TextStrokeTransparency = 0.7 })
                :Play()
            task.wait(2.6)
            local out = TweenService:Create(
                gui.Toast,
                FADE,
                { TextTransparency = 1, TextStrokeTransparency = 1 }
            )
            out:Play()
            out.Completed:Wait()
        end
        toasting = false
    end)
end

Remotes.Notify.OnClientEvent:Connect(toast)

Remotes.CrateResult.OnClientEvent:Connect(function(r)
    if r.announce then
        toast(("%s pulled %s · %s"):format(r.player, r.item, string.upper(r.rarity)))
    elseif r.crafted then
        local item = Catalog[r.id]
        toast(
            ("CRAFTED %s · %s"):format(
                item and string.upper(item.name) or "?",
                string.upper(r.rarity)
            )
        )
    end
    -- Own pulls spin on the crate screen; rank gifts arrive with a Notify
end)

Remotes.ShopResult.OnClientEvent:Connect(function(_ok, message: string)
    -- The crate and inventory screens show these inline
    if ClientState.screen ~= "crate" and ClientState.screen ~= "inventory" then
        toast(message)
    end
end)

Remotes.TradeComplete.OnClientEvent:Connect(function()
    toast("Trade complete.")
end)

---------------------------------------------------------------- Hints
-- Three ghost prompts, once each per account. No tutorial level.
local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local HINT_TEXT = {
    move = touch and "Drag the thumbstick to move" or "WASD to move",
    examine = touch and "Tap USE to examine a body" or "E to examine a body",
    coins = "Coins are on the floor",
}
local shown: { [string]: boolean } = {}
local hintBusy = false

local function showHint(id: string)
    if shown[id] or not ClientState.loaded or ClientState.data.hintsSeen[id] then
        return
    end
    while hintBusy do
        task.wait(0.25)
    end
    if shown[id] then
        return
    end
    shown[id] = true
    hintBusy = true
    gui.Hint.Text = HINT_TEXT[id]
    TweenService:Create(gui.Hint, FADE, { TextTransparency = 0.15 }):Play()
    task.wait(3.5)
    local out = TweenService:Create(gui.Hint, FADE, { TextTransparency = 1 })
    out:Play()
    out.Completed:Wait()
    hintBusy = false
    ClientState.data.hintsSeen[id] = true
    Remotes.HintSeen:FireServer(id)
end

task.spawn(function()
    while true do
        task.wait(0.25)
        if ClientState.GetRoundState() ~= "ACTIVE" or not ClientState.role or shown.examine then
            continue
        end
        local char = plr.Character
        if not char then
            continue
        end
        local here = char:GetPivot().Position
        for _, body in CollectionService:GetTagged("Body") do
            if
                body:IsA("Model")
                and (body:GetPivot().Position - here).Magnitude <= Config.EXAMINE_RANGE * 2
            then
                task.spawn(showHint, "examine")
                break
            end
        end
    end
end)

ReplicatedStorage:GetAttributeChangedSignal("RoundState"):Connect(function()
    if ClientState.GetRoundState() == "ACTIVE" and ClientState.role then
        task.spawn(showHint, "move")
        task.delay(6, function()
            if ClientState.GetRoundState() == "ACTIVE" then
                showHint("coins")
            end
        end)
    end
end)

return NoticeController
