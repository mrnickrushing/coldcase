local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local Catalog = require(game.ReplicatedStorage.Shared.Catalog)
local LiveOps = require(game.ReplicatedStorage.Shared.LiveOps)
local Remotes = game.ReplicatedStorage.Remotes
local DataService = require(script.Parent.DataService)
local Analytics = require(script.Parent.Analytics)
local LiveOpsClock = require(script.Parent.LiveOpsClock)

local TradeService = {}
local sessions = {} -- [id] = session
local sessionOf = {} -- [Player] = id
local invites = {} -- [Player] = Player they asked to trade with
local MAX_OFFER = 8

local function push(s)
    Remotes.TradeUpdate:FireClient(
        s.a,
        s.id,
        s.offerA,
        s.offerB,
        s.lockA,
        s.lockB,
        s.confirmA,
        s.confirmB
    )
    Remotes.TradeUpdate:FireClient(
        s.b,
        s.id,
        s.offerB,
        s.offerA,
        s.lockB,
        s.lockA,
        s.confirmB,
        s.confirmA
    )
end

-- Any change to the table resets both locks and both confirms. Non-negotiable.
local function invalidate(s)
    s.lockA, s.lockB, s.confirmA, s.confirmB = false, false, false, false
    push(s)
end

local function valueOf(entries): number
    local total = 0
    for _, it in entries do
        local item = Catalog[it.id]
        total += item and item.value or 0
    end
    return total
end

function TradeService:Open(a: Player, b: Player)
    if sessionOf[a] or sessionOf[b] then
        return
    end
    local id = HttpService:GenerateGUID(false)
    local s = {
        id = id,
        a = a,
        b = b,
        offerA = {},
        offerB = {},
        lockA = false,
        lockB = false,
        confirmA = false,
        confirmB = false,
    }
    sessions[id] = s
    sessionOf[a], sessionOf[b] = id, id
    invites[a], invites[b] = nil, nil
    push(s)
end

-- Both players must ask for each other before a table opens
function TradeService:Invite(from: Player, to: Player)
    if to == from or to.Parent ~= Players then
        return
    end
    if not LiveOps.IsTradingOpen(LiveOpsClock.Day()) then
        return
    end
    if not (DataService:Get(from) and DataService:Get(to)) then
        return
    end
    if invites[to] == from then
        self:Open(from, to)
    else
        invites[from] = to
        Remotes.Notify:FireClient(to, ("%s wants to trade"):format(from.DisplayName))
    end
end

function TradeService:SetOffer(plr: Player, uids: any)
    local s = sessions[sessionOf[plr]]
    if not s or type(uids) ~= "table" or #uids > MAX_OFFER then
        return
    end
    local data = DataService:Get(plr)
    if not data then
        return
    end

    -- Verify every uid is a unique string actually owned RIGHT NOW
    local seen, clean = {}, {}
    for _, uid in uids do
        if type(uid) ~= "string" or seen[uid] then
            return
        end
        seen[uid] = true
        local owned = false
        for _, item in data.inventory do
            if item.uid == uid then
                owned = true
                break
            end
        end
        if not owned then
            return
        end
        table.insert(clean, uid)
    end

    if plr == s.a then
        s.offerA = clean
    else
        s.offerB = clean
    end
    invalidate(s)
end

function TradeService:Lock(plr: Player)
    local s = sessions[sessionOf[plr]]
    if not s then
        return
    end
    if plr == s.a then
        s.lockA = true
    else
        s.lockB = true
    end
    push(s)
end

function TradeService:Confirm(plr: Player)
    local s = sessions[sessionOf[plr]]
    if not s or not (s.lockA and s.lockB) then
        return
    end
    if plr == s.a then
        s.confirmA = true
    else
        s.confirmB = true
    end
    if s.confirmA and s.confirmB then
        self:Execute(s)
    else
        push(s)
    end
end

function TradeService:Execute(s)
    local da, db = DataService:Get(s.a), DataService:Get(s.b)
    if not (da and db) then
        return
    end

    -- Re-verify ownership at the moment of transfer, in the same synchronous
    -- block as the removal. Nothing in here may yield.
    local function pull(data, uids)
        local out = {}
        for _, uid in uids do
            for i, item in data.inventory do
                if item.uid == uid then
                    table.insert(out, table.remove(data.inventory, i))
                    break
                end
            end
        end
        return out
    end

    local fromA, fromB = pull(da, s.offerA), pull(db, s.offerB)
    if #fromA ~= #s.offerA or #fromB ~= #s.offerB then
        -- Something moved mid-trade. Put it all back and abort; nothing is lost.
        for _, it in fromA do
            table.insert(da.inventory, it)
        end
        for _, it in fromB do
            table.insert(db.inventory, it)
        end
        invalidate(s)
        return
    end

    for _, it in fromA do
        table.insert(db.inventory, it)
    end
    for _, it in fromB do
        table.insert(da.inventory, it)
    end

    Analytics.TradeComplete(s.a, valueOf(fromA), valueOf(fromB))
    Remotes.TradeComplete:FireClient(s.a)
    Remotes.TradeComplete:FireClient(s.b)
    DataService:PushToClient(s.a)
    DataService:PushToClient(s.b)
    self:Close(s)
end

function TradeService:Close(s)
    sessionOf[s.a], sessionOf[s.b] = nil, nil
    sessions[s.id] = nil
    for _, plr in { s.a, s.b } do
        if plr.Parent == Players then
            Remotes.TradeUpdate:FireClient(plr, s.id, nil)
        end
    end
end

function TradeService:Handle(plr: Player, action: any, payload: any)
    if action == "open" then
        if typeof(payload) == "Instance" and payload:IsA("Player") then
            self:Invite(plr, payload)
        end
    elseif action == "offer" then
        self:SetOffer(plr, payload)
    elseif action == "lock" then
        self:Lock(plr)
    elseif action == "confirm" then
        self:Confirm(plr)
    elseif action == "cancel" then
        local s = sessions[sessionOf[plr]]
        if s then
            self:Close(s)
        end
    end
end

Players.PlayerRemoving:Connect(function(plr)
    invites[plr] = nil
    local s = sessions[sessionOf[plr]]
    if s then
        TradeService:Close(s)
    end
end)

return TradeService
