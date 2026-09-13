--!strict
-- The Radio and Emote passes, and player reports.
-- Handbook rule: sell identity, not advantage. Radio is refused to the dead
-- during a round — a spectator feeding the living breaks deduction.
local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")
local TextService = game:GetService("TextService")
local Config = require(game.ReplicatedStorage.Shared.Config)
local Remotes = game.ReplicatedStorage.Remotes
local MonetizationService = require(script.Parent.MonetizationService)
local RoundService = require(script.Parent.RoundService)
local Analytics = require(script.Parent.Analytics)

local SocialService = {}
local lastRadio: { [Player]: number } = {}
local lastEmote: { [Player]: number } = {}
local reportedBy: { [Player]: { [number]: boolean } } = {}
local reportCount: { [number]: number } = {} -- UserId -> reports this server

local function cooled(last: { [Player]: number }, plr: Player, cooldown: number): boolean
    local now = os.clock()
    if now - (last[plr] or 0) < cooldown then
        return false
    end
    last[plr] = now
    return true
end

local function mayTransmit(plr: Player): boolean
    return RoundService:GetState() ~= "ACTIVE" or RoundService:IsAlive(plr)
end

function SocialService:Radio(plr: Player, message: string)
    if not MonetizationService:HasPass(plr, "radio") or not mayTransmit(plr) then
        return
    end
    local text = string.match(message, "^%s*(.-)%s*$") or ""
    local length = utf8.len(text)
    if not length or length == 0 or length > Config.RADIO_MAX_CHARS then
        return
    end
    if not cooled(lastRadio, plr, Config.RADIO_COOLDOWN) then
        return
    end

    -- Players whose account settings disable chat do not get to broadcast
    local okChat, canChat = pcall(TextChatService.CanUserChatAsync, TextChatService, plr.UserId)
    if okChat and canChat == false then
        return
    end
    local ok, filtered = pcall(function()
        local result =
            TextService:FilterStringAsync(text, plr.UserId, Enum.TextFilterContext.PublicChat)
        return result:GetNonChatStringForBroadcastAsync()
    end)
    -- The filter yields: the sender may have left or died in the meantime
    if not ok or type(filtered) ~= "string" or filtered == "" then
        return
    end
    if plr.Parent ~= Players or not mayTransmit(plr) then
        return
    end
    Remotes.RadioMessage:FireAllClients(plr.DisplayName, filtered)
end

function SocialService:Emote(plr: Player, emoteId: string)
    if not MonetizationService:HasPass(plr, "emotes") or not table.find(Config.EMOTES, emoteId) then
        return
    end
    local hum = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 or not cooled(lastEmote, plr, Config.EMOTE_COOLDOWN) then
        return
    end
    Remotes.EmotePlayed:FireAllClients(plr, emoteId)
end

-- Roblox's own report flow does the moderation; this feeds the dashboard.
-- One report per reporter per player per session.
function SocialService:Report(plr: Player, target: Player, reason: string)
    if
        target == plr
        or target.Parent ~= Players
        or not table.find(Config.REPORT_REASONS, reason)
    then
        return
    end
    local mine = reportedBy[plr]
    if not mine then
        mine = {}
        reportedBy[plr] = mine
    end
    if mine[target.UserId] then
        Remotes.Notify:FireClient(plr, ("You already reported %s."):format(target.DisplayName))
        return
    end
    mine[target.UserId] = true
    reportCount[target.UserId] = (reportCount[target.UserId] or 0) + 1
    Analytics.PlayerReport(plr, reason, reportCount[target.UserId])
    Remotes.Notify:FireClient(plr, ("Reported %s. Thank you."):format(target.DisplayName))
end

Players.PlayerRemoving:Connect(function(plr)
    lastRadio[plr], lastEmote[plr], reportedBy[plr] = nil, nil, nil
end)

return SocialService
