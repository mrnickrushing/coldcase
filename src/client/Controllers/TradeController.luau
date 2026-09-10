-- StarterPlayerScripts/Controllers/TradeController
-- Drives TradeGui. The server owns the table; this only shows it and asks.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared.Theme)
local Catalog = require(Shared.Catalog)
local ItemCard = require(Shared.Build.ItemCard)
local ClientState = require(script.Parent.Parent.ClientState)

local plr = Players.LocalPlayer
local gui = plr:WaitForChild("PlayerGui"):WaitForChild("TradeGui")
local root = gui:WaitForChild("Root")
local TradeController = {}

local MAX_OFFER = 8
local GREEN = Color3.fromHex("4fb0a0")
local QUIET_STROKE = Color3.fromHex("1f252e")

type Entry = { uid: string, id: string, effect: string? }
local session: {
    id: string,
    mine: { Entry },
    theirs: { Entry },
    myLock: boolean,
    theirLock: boolean,
    myConfirm: boolean,
    theirConfirm: boolean,
    partner: Player?,
}? =
    nil

local function setEnabled(b: TextButton, on: boolean)
    b.AutoButtonColor = on
    b.BackgroundTransparency = on and 0 or 0.5
    b.TextTransparency = on and 0 or 0.45
end

local function status(text: string, colour: Color3?)
    root.Status.Text = text
    root.Status.TextColor3 = colour or Theme.MUTED
end

local function valueOf(entries: { Entry }): number
    local total = 0
    for _, e in entries do
        local def = Catalog[e.id]
        total += def and def.value or 0
    end
    return total
end

local function inLiveRound(): boolean
    local st = ClientState.GetRoundState()
    return ClientState.role ~= nil and st ~= "INTERMISSION" and st ~= "RESOLUTION"
end

local function clearCards(container: Instance)
    for _, c in container:GetChildren() do
        if c:IsA("Frame") then
            c:Destroy()
        end
    end
end

local function sendOffer(uids: { string })
    Remotes.RequestTrade:FireServer("offer", uids)
end

local function lockLabel(lock: boolean, confirm: boolean, idle: string): (string, Color3)
    if confirm then
        return "CONFIRMED", GREEN
    elseif lock then
        return "LOCKED", GREEN
    end
    return idle, Theme.MUTED
end

local function render()
    local s = session
    if not s then
        return
    end
    root.Header.Title.Text = ("TRADE WITH %s"):format(
        string.upper(s.partner and s.partner.DisplayName or "?")
    )

    clearCards(root.Mine.Slots)
    for i, e in s.mine do
        local card = ItemCard.new(root.Mine.Slots, e.id, nil, true)
        card.LayoutOrder = i
        card.Button.Activated:Connect(function()
            local uids = {}
            for _, other in s.mine do
                if other.uid ~= e.uid then
                    table.insert(uids, other.uid)
                end
            end
            sendOffer(uids)
        end)
    end
    clearCards(root.Theirs.Slots)
    for i, e in s.theirs do
        ItemCard.new(root.Theirs.Slots, e.id).LayoutOrder = i
    end

    root.Mine.Lock.Text, root.Mine.Lock.TextColor3 = lockLabel(s.myLock, s.myConfirm, "Editing")
    root.Theirs.Lock.Text, root.Theirs.Lock.TextColor3 =
        lockLabel(s.theirLock, s.theirConfirm, "Choosing")
    root.Mine.Stroke.Color = s.myLock and GREEN or QUIET_STROKE
    root.Theirs.Stroke.Color = s.theirLock and GREEN or QUIET_STROKE

    local mineV, theirV = valueOf(s.mine), valueOf(s.theirs)
    root.Mine.Value.Text = ("Table value · %d"):format(mineV)
    root.Theirs.Value.Text = ("Table value · %d"):format(theirV)

    -- Fairness meter, mirroring the prototype
    local total = mineV + theirV
    local ratio = total > 0 and (theirV - mineV) / total or 0
    local even = math.abs(ratio) < 0.08
    local fill = root.Fairness.Track.Fill
    fill.Position = UDim2.fromScale(math.min(0.5, 0.5 + ratio * 0.5), 0)
    fill.Size = UDim2.fromScale(math.abs(ratio * 0.5), 1)
    fill.BackgroundColor3 = if even then GREEN elseif ratio > 0 then Theme.CYAN else Theme.DANGER
    root.Fairness.Label.Text = if total == 0
        then "Empty table"
        elseif even then "Even trade"
        elseif ratio > 0 then "In your favour"
        else "You are losing value"

    local buttons = root.Buttons
    buttons.Lock.Text = s.myLock and "UNLOCK" or "LOCK MY OFFER"
    local canConfirm = s.myLock and s.theirLock and not s.myConfirm
    buttons.Confirm.Text = s.myConfirm and "WAITING…" or "CONFIRM TRADE"
    buttons.Confirm.BackgroundColor3 = canConfirm and Theme.AMBER or Color3.fromHex("2b323c")
    setEnabled(buttons.Confirm, canConfirm)

    local pool = root.Pool.Items
    clearCards(pool)
    local onTable = {}
    for _, e in s.mine do
        onTable[e.uid] = true
    end
    local inventory: { any } = ClientState.data.inventory or {}
    for i, item in inventory do
        local card = ItemCard.new(pool, item.id, nil, true)
        card.LayoutOrder = i
        if onTable[item.uid] then
            card.BackgroundTransparency = 0.6
            card.Stroke.Transparency = 0.6
        end
        card.Button.Activated:Connect(function()
            if onTable[item.uid] then
                return
            end
            local uids = {}
            for _, e in s.mine do
                table.insert(uids, e.uid)
            end
            if #uids >= MAX_OFFER then
                status(("%d items is the limit."):format(MAX_OFFER))
                return
            end
            table.insert(uids, item.uid)
            sendOffer(uids)
        end)
    end
end

Remotes.TradeUpdate.OnClientEvent:Connect(
    function(id, mine, theirs, myLock, theirLock, myConfirm, theirConfirm, partner)
        if mine == nil then
            if session and session.id == id then
                session = nil
                if gui.Enabled and ClientState.ShowScreen then
                    ClientState.ShowScreen("lobby")
                end
            end
            return
        end

        local previous = session
        session = {
            id = id,
            mine = mine,
            theirs = theirs,
            myLock = myLock,
            theirLock = theirLock,
            myConfirm = myConfirm,
            theirConfirm = theirConfirm,
            partner = partner,
        }
        if
            previous
            and previous.id == id
            and (previous.myLock or previous.theirLock)
            and not (myLock or theirLock)
        then
            status("Table changed. Both locks reset.")
        elseif myLock and theirLock then
            status("Both sides locked. Confirm to execute.", GREEN)
        elseif myLock then
            status("Locked. Waiting for them…")
        elseif not previous then
            status("")
        end

        if not gui.Enabled and not inLiveRound() and ClientState.ShowScreen then
            ClientState.ShowScreen("trade")
        end
        render()
    end
)

Remotes.TradeComplete.OnClientEvent:Connect(function()
    status("Trade complete. Items moved to your collection.", GREEN)
end)

ClientState.On("data", function()
    if session and gui.Enabled then
        render()
    end
end)

root.Buttons.Lock.Activated:Connect(function()
    local s = session
    if not s then
        return
    end
    if s.myLock then
        Remotes.RequestTrade:FireServer("unlock")
    elseif #s.mine == 0 then
        status("Put something on the table first.")
    else
        Remotes.RequestTrade:FireServer("lock")
    end
end)

root.Buttons.Confirm.Activated:Connect(function()
    local s = session
    if s and s.myLock and s.theirLock and not s.myConfirm then
        Remotes.RequestTrade:FireServer("confirm")
        status("Escrow holding. Verifying ownership on both sides…")
    end
end)

root.Buttons.Cancel.Activated:Connect(function()
    if session then
        Remotes.RequestTrade:FireServer("cancel")
    end
    if ClientState.ShowScreen then
        ClientState.ShowScreen("lobby")
    end
end)

return TradeController
