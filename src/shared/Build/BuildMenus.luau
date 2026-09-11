--[[
  COLD CASE · menu builder (Claude Design's BuildMenus, in the Theme)
  MenuController calls this at runtime with the PlayerGui. To bake the
  screens into StarterGui instead:
    require(game.ReplicatedStorage.Shared.Build.BuildMenus)()

  Every screen is a full-screen Backdrop plus a fixed-size Root with a UIScale
  named Scale, so the controller can shrink the layout to fit a phone.
    LobbyGui      map vote, player list with TRADE, rank bar, Locker, Robux store
    ResultsGui    reveal, roster, kill timeline, payout, near-miss
    CrateGui      Locker/Seasonal tabs, reel, published odds, direct-buy shelf
    InventoryGui  collection grid, equip, craft, effect re-roll
    TradeGui      escrowed swap with lock/confirm and fairness meter
]]
local Theme = require(script.Parent.Parent.Theme)
local Config = require(script.Parent.Parent.Config)
local Rarities = require(script.Parent.Parent.RarityTable)

local BG = Theme.GROUND
local PANEL = Theme.PANEL
local SUNK = Color3.fromHex("0f1318")
local STROKE = Color3.fromHex("1f252e")
local RAISED = Color3.fromHex("161b22")
local GREEN = Color3.fromHex("4fb0a0")
local ROOT_SIZE = Vector2.new(1040, 640)

local function screen(
    parent: Instance,
    name: string,
    order: number,
    backdrop: number
): (ScreenGui, Frame)
    local old = parent:FindFirstChild(name)
    if old then
        old:Destroy()
    end
    local g = Instance.new("ScreenGui")
    g.Name = name
    g.IgnoreGuiInset = true
    g.ResetOnSpawn = false
    g.Enabled = false
    g.DisplayOrder = order
    g.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    local back = Instance.new("Frame")
    back.Name = "Backdrop"
    back.Size = UDim2.fromScale(1, 1)
    back.BackgroundColor3 = BG
    back.BackgroundTransparency = backdrop
    back.BorderSizePixel = 0
    back.Active = true -- menus sink input so clicks never reach the world
    back.Parent = g

    local root = Instance.new("Frame")
    root.Name = "Root"
    root.AnchorPoint = Vector2.new(0.5, 0.5)
    root.Position = UDim2.fromScale(0.5, 0.5)
    root.Size = UDim2.fromOffset(ROOT_SIZE.X, ROOT_SIZE.Y)
    root.BackgroundTransparency = 1
    root.Parent = g
    local scale = Instance.new("UIScale")
    scale.Name = "Scale"
    scale.Parent = root

    g.Parent = parent
    return g, root
end

local function frame(
    name: string,
    parent: Instance,
    size: UDim2,
    pos: UDim2?,
    colour: Color3?,
    transparent: boolean?
): Frame
    local f = Instance.new("Frame")
    f.Name = name
    f.Size = size
    f.Position = pos or UDim2.new()
    f.BackgroundColor3 = colour or PANEL
    f.BackgroundTransparency = transparent and 1 or 0
    f.BorderSizePixel = 0
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 6)
    c.Parent = f
    f.Parent = parent
    return f
end

local function stroke(f: Instance, colour: Color3?)
    local s = Instance.new("UIStroke")
    s.Name = "Stroke"
    s.Color = colour or STROKE
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent = f
    return s
end

local function pad(f: Instance, n: number)
    local p = Instance.new("UIPadding")
    p.PaddingLeft = UDim.new(0, n)
    p.PaddingRight = UDim.new(0, n)
    p.PaddingTop = UDim.new(0, n)
    p.PaddingBottom = UDim.new(0, n)
    p.Parent = f
end

local function text(
    name: string,
    parent: Instance,
    str: string,
    size: number,
    colour: Color3?,
    font: Font?,
    align: Enum.TextXAlignment?
): TextLabel
    local l = Instance.new("TextLabel")
    l.Name = name
    l.Text = str
    l.FontFace = font or Theme.MONO
    l.TextSize = size
    l.TextColor3 = colour or Theme.INK
    l.BackgroundTransparency = 1
    l.TextXAlignment = align or Enum.TextXAlignment.Left
    l.Size = UDim2.new(1, 0, 0, size + 6)
    l.Parent = parent
    return l
end

local function button(
    name: string,
    parent: Instance,
    str: string,
    size: UDim2,
    fill: Color3?,
    fg: Color3?
): TextButton
    local b = Instance.new("TextButton")
    b.Name = name
    b.Text = str
    b.FontFace = Theme.DISPLAY
    b.TextSize = 20
    b.TextColor3 = fg or BG
    b.BackgroundColor3 = fill or Theme.AMBER
    b.Size = size
    b.BorderSizePixel = 0
    b.AutoButtonColor = true
    local limit = Instance.new("UITextSizeConstraint")
    limit.MaxTextSize = 20
    limit.Parent = b
    b.TextScaled = true
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 6)
    c.Parent = b
    local p = Instance.new("UIPadding")
    p.PaddingLeft = UDim.new(0, 8)
    p.PaddingRight = UDim.new(0, 8)
    p.PaddingTop = UDim.new(0, 6)
    p.PaddingBottom = UDim.new(0, 6)
    p.Parent = b
    b.Parent = parent
    return b
end

local function list(
    parent: Instance,
    dir: Enum.FillDirection?,
    gap: number?,
    align: Enum.HorizontalAlignment?
)
    local l = Instance.new("UIListLayout")
    l.FillDirection = dir or Enum.FillDirection.Vertical
    l.Padding = UDim.new(0, gap or 8)
    l.SortOrder = Enum.SortOrder.LayoutOrder
    l.HorizontalAlignment = align or Enum.HorizontalAlignment.Left
    l.Parent = parent
end

local function grid(parent: Instance, cell: UDim2, gap: number)
    local g = Instance.new("UIGridLayout")
    g.CellSize = cell
    g.CellPadding = UDim2.fromOffset(gap, gap)
    g.SortOrder = Enum.SortOrder.LayoutOrder
    g.Parent = parent
end

local function scroller(name: string, parent: Instance, size: UDim2, pos: UDim2): ScrollingFrame
    local s = Instance.new("ScrollingFrame")
    s.Name = name
    s.Size = size
    s.Position = pos
    s.BackgroundTransparency = 1
    s.BorderSizePixel = 0
    s.ScrollBarThickness = 6
    s.CanvasSize = UDim2.new()
    s.AutomaticCanvasSize = Enum.AutomaticSize.Y
    s.Parent = parent
    return s
end

local function header(parent: Instance, kicker: string, title: string)
    local h = frame("Header", parent, UDim2.new(1, 0, 0, 78), nil, nil, true)
    text("Kicker", h, kicker, 11, Theme.AMBER)
    local t = text("Title", h, title, 44, Theme.INK, Theme.DISPLAY_HEAVY)
    t.Position = UDim2.new(0, 0, 0, 20)
    t.Size = UDim2.new(1, 0, 0, 52)
    return h
end

return function(parent: Instance?)
    parent = parent or game:GetService("StarterGui")
    local out = {}

    ------------------------------------------------------------------ LOBBY
    do
        local g, root = screen(parent :: Instance, "LobbyGui", 5, 0.35)
        pad(root, 26)
        local h = header(root, "INTERMISSION", "VOTE THE SCENE")
        local countdown =
            text("Countdown", h, "", 14, Theme.SOFT, Theme.MONO, Enum.TextXAlignment.Right)
        countdown.Position = UDim2.new(0, 0, 0, 2)

        local maps = frame("Maps", root, UDim2.new(1, 0, 0, 210), UDim2.new(0, 0, 0, 92), nil, true)
        grid(maps, UDim2.new(1 / 3, -8, 1, 0), 12)
        for i, mapName in Config.MAPS do
            local card = frame("Map" .. i, maps, UDim2.new())
            card:SetAttribute("MapName", mapName)
            card.LayoutOrder = i
            stroke(card)
            local preview = frame("Preview", card, UDim2.new(1, 0, 0, 104), nil, RAISED)
            local image = (Config.MAP_IMAGES :: { [string]: string })[mapName]
            if image and image ~= "" then
                local plan = Instance.new("ImageLabel")
                plan.Name = "Plan"
                plan.BackgroundTransparency = 1
                plan.Size = UDim2.fromScale(1, 1)
                plan.Image = image
                plan.ScaleType = Enum.ScaleType.Crop
                plan.Parent = preview
                local corner = Instance.new("UICorner")
                corner.CornerRadius = UDim.new(0, 6)
                corner.Parent = plan
            end
            local body =
                frame("Body", card, UDim2.new(1, 0, 1, -104), UDim2.new(0, 0, 0, 104), nil, true)
            pad(body, 12)
            local n = text(
                "MapName",
                body,
                string.upper((mapName:gsub("(%l)(%u)", "%1 %2"))),
                20,
                Theme.INK,
                Theme.DISPLAY
            )
            n.Size = UDim2.new(1, -50, 0, 26)
            local votes =
                text("Votes", body, "0", 13, Theme.AMBER, Theme.MONO, Enum.TextXAlignment.Right)
            votes.Size = UDim2.new(0, 44, 0, 26)
            votes.Position = UDim2.new(1, -44, 0, 0)
            local barBg = frame(
                "BarBg",
                body,
                UDim2.new(1, 0, 0, 4),
                UDim2.new(0, 0, 0, 34),
                Color3.fromHex("1c222a")
            )
            frame("Bar", barBg, UDim2.new(0, 0, 1, 0), nil, Theme.AMBER)
            local vote = button("Vote", body, "VOTE", UDim2.new(1, 0, 0, Theme.TAP_MIN))
            vote.Position = UDim2.new(0, 0, 1, -Theme.TAP_MIN)
        end

        local players = frame("Players", root, UDim2.new(0.48, -6, 0, 214), UDim2.new(0, 0, 0, 316))
        stroke(players)
        pad(players, 14)
        text("Caption", players, "IN LOBBY", 10, Theme.DIM)
        local plist = scroller("List", players, UDim2.new(1, 0, 1, -22), UDim2.new(0, 0, 0, 22))
        list(plist, nil, 6)
        local row = frame("RowTemplate", plist, UDim2.new(1, -8, 0, 32), nil, nil, true)
        row.Visible = false
        local rn = text("PlayerName", row, "", 15, Theme.INK, Theme.DISPLAY)
        rn.Size = UDim2.new(0.38, 0, 1, 0)
        local rr = text("Rank", row, "", 11, Theme.MUTED)
        rr.Position = UDim2.new(0.38, 0, 0, 0)
        rr.Size = UDim2.new(0.3, 0, 1, 0)
        local trade = button("Trade", row, "TRADE", UDim2.new(0.16, -4, 1, 0), RAISED, Theme.CYAN)
        trade.Position = UDim2.new(0.68, 0, 0, 0)
        stroke(trade, Theme.CYAN)
        local report =
            button("Report", row, "REPORT", UDim2.new(0.16, 0, 1, 0), RAISED, Theme.MUTED)
        report.Position = UDim2.new(0.84, 0, 0, 0)
        stroke(report)

        local side = frame("Side", root, UDim2.new(0.52, -6, 0, 214), UDim2.new(0.48, 6, 0, 316))
        stroke(side)
        pad(side, 14)
        text("RankCaption", side, "RANK", 10, Theme.DIM)
        local rank = text("Rank", side, "1 · BYSTANDER", 24, Theme.INK, Theme.DISPLAY)
        rank.Position = UDim2.new(0, 0, 0, 14)
        local xpBg = frame(
            "XpBg",
            side,
            UDim2.new(1, 0, 0, 8),
            UDim2.new(0, 0, 0, 48),
            Color3.fromHex("1c222a")
        )
        frame("Xp", xpBg, UDim2.new(0, 0, 1, 0), nil, Theme.CYAN)
        local xpText = text("XpText", side, "0 / 1200 XP", 11, Theme.DIM)
        xpText.Position = UDim2.new(0, 0, 0, 60)
        local coins = text("Coins", side, "0 COINS", 24, Theme.AMBER, Theme.DISPLAY)
        coins.Position = UDim2.new(0, 0, 0, 82)
        local keys = text("Keys", side, "", 11, Theme.SOFT, Theme.MONO, Enum.TextXAlignment.Right)
        keys.Position = UDim2.new(0, 0, 0, 90)

        local row2 = frame(
            "Buttons",
            side,
            UDim2.new(1, 0, 0, Theme.TAP_MIN),
            UDim2.new(0, 0, 1, -Theme.TAP_MIN),
            nil,
            true
        )
        list(row2, Enum.FillDirection.Horizontal, 8)
        button("OpenCrate", row2, "CRATE", UDim2.new(0.5, -4, 1, 0)).LayoutOrder = 1
        local inv = button(
            "OpenInventory",
            row2,
            "COLLECTION",
            UDim2.new(0.5, -4, 1, 0),
            RAISED,
            Theme.CYAN
        )
        inv.LayoutOrder = 2
        stroke(inv, Theme.CYAN)

        -- Robux store. Entries with a product id of 0 stay hidden.
        local store =
            frame("Store", root, UDim2.new(1, 0, 0, 40), UDim2.new(0, 0, 0, 548), nil, true)
        list(store, Enum.FillDirection.Horizontal, 8)
        for i, key in { "vip", "coins2500", "seasonalKey" } do
            local b = button(key, store, "", UDim2.new(0, 220, 1, 0), RAISED, Theme.SOFT)
            b.LayoutOrder = i
            b.Visible = false
            stroke(b, Color3.fromHex("2b323c"))
        end
        out.lobby = g
    end

    ------------------------------------------------------------------ RESULTS
    do
        local g = screen(parent :: Instance, "ResultsGui", 6, 0.35)
        local card = g.Root
        card.Size = UDim2.fromOffset(620, 640)
        card.BackgroundColor3 = Theme.CARD
        card.BackgroundTransparency = 0
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 6)
        corner.Parent = card
        stroke(card, Theme.STROKE)
        card.ClipsDescendants = true

        local banner = frame("Banner", card, UDim2.new(1, 0, 0, 104), nil, Theme.AMBER)
        local bk = text("Kicker", banner, "ROUND OVER", 11, BG)
        bk.Position = UDim2.new(0, 26, 0, 22)
        local bt = text("Title", banner, "YOU WON", 46, BG, Theme.DISPLAY_HEAVY)
        bt.Position = UDim2.new(0, 26, 0, 40)
        bt.Size = UDim2.new(1, -52, 0, 54)

        local reveal = frame(
            "Reveal",
            card,
            UDim2.new(1, 0, 0, 170),
            UDim2.new(0, 0, 0, 104),
            Color3.fromHex("0d1015")
        )
        pad(reveal, 22)
        text("Caption", reveal, "THE REVEAL", 10, Theme.DIM)
        local swatch =
            frame("Swatch", reveal, UDim2.new(0, 48, 0, 48), UDim2.new(0, 0, 0, 22), Theme.DANGER)
        swatch.Rotation = 45
        local killer = text("KillerName", reveal, "—", 32, Theme.DANGER, Theme.DISPLAY_HEAVY)
        killer.Position = UDim2.new(0, 66, 0, 20)
        killer.Size = UDim2.new(1, -66, 0, 38)
        local tally = text("KillerTally", reveal, "", 11, Theme.MUTED)
        tally.Position = UDim2.new(0, 66, 0, 56)
        local roster =
            frame("Roster", reveal, UDim2.new(1, 0, 0, 56), UDim2.new(0, 0, 0, 80), nil, true)
        grid(roster, UDim2.fromOffset(136, 24), 6)

        local lower =
            frame("Lower", card, UDim2.new(1, 0, 1, -274), UDim2.new(0, 0, 0, 274), nil, true)
        pad(lower, 22)
        local blurb = text("Blurb", lower, "", 14, Theme.SOFT)
        blurb.Size = UDim2.new(1, 0, 0, 36)
        blurb.TextWrapped = true

        local tl = frame("Timeline", lower, UDim2.new(1, 0, 0, 96), UDim2.new(0, 0, 0, 40), SUNK)
        stroke(tl)
        pad(tl, 10)
        text("Caption", tl, "KILL TIMELINE", 10, Theme.DIM)
        local tlList = frame("List", tl, UDim2.new(1, 0, 1, -18), UDim2.new(0, 0, 0, 18), nil, true)
        list(tlList, nil, 2)

        local rewards =
            frame("Rewards", lower, UDim2.new(1, 0, 0, 84), UDim2.new(0, 0, 0, 144), nil, true)
        list(rewards, nil, 4)
        for i, spec in
            {
                { "Xp", "EXPERIENCE", Theme.CYAN },
                { "Coins", "COINS BANKED", Theme.AMBER },
                { "Clues", "EVIDENCE READ", Theme.INK },
            }
        do
            local r = frame(spec[1], rewards, UDim2.new(1, 0, 0, 24), nil, nil, true)
            r.LayoutOrder = i
            text("Label", r, spec[2], 11, Theme.MUTED).Size = UDim2.new(1, 0, 1, 0)
            local v = text("Value", r, "0", 20, spec[3], Theme.DISPLAY, Enum.TextXAlignment.Right)
            v.Size = UDim2.new(1, 0, 1, 0)
        end
        local nearMiss = text("NearMiss", lower, "", 13, Theme.SOFT)
        nearMiss.Position = UDim2.new(0, 0, 0, 232)

        local btns = frame(
            "Buttons",
            lower,
            UDim2.new(1, 0, 0, Theme.TAP_MIN),
            UDim2.new(0, 0, 1, -Theme.TAP_MIN),
            nil,
            true
        )
        list(btns, Enum.FillDirection.Horizontal, 10)
        button("NextRound", btns, "NEXT ROUND", UDim2.new(0.5, -5, 1, 0)).LayoutOrder = 1
        local oc = button(
            "OpenCrate",
            btns,
            "OPEN CRATE",
            UDim2.new(0.5, -5, 1, 0),
            Theme.CARD,
            Theme.CYAN
        )
        oc.LayoutOrder = 2
        stroke(oc, Theme.CYAN)
        out.results = g
    end

    ------------------------------------------------------------------ CRATE
    do
        local g, root = screen(parent :: Instance, "CrateGui", 6, 0.06)
        pad(root, 26)
        local h = header(root, "EVIDENCE CRATE", "THE LOCKER")

        local tabs = frame("Tabs", h, UDim2.new(0, 360, 0, 36), UDim2.new(1, -360, 0, 0), nil, true)
        list(tabs, Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Right)
        for i, key in { "Locker", "Seasonal" } do
            local t =
                button(key, tabs, string.upper(key), UDim2.new(0, 150, 1, 0), RAISED, Theme.MUTED)
            t.LayoutOrder = i
            stroke(t, Color3.fromHex("2b323c"))
        end
        local countdown =
            text("Countdown", h, "", 11, Theme.SOFT, Theme.MONO, Enum.TextXAlignment.Right)
        countdown.Position = UDim2.new(0, 0, 0, 48)

        local reelBox = frame(
            "ReelBox",
            root,
            UDim2.new(1, 0, 0, 182),
            UDim2.new(0, 0, 0, 92),
            Color3.fromHex("0e1116")
        )
        stroke(reelBox)
        reelBox.ClipsDescendants = true
        local reel =
            frame("Reel", reelBox, UDim2.new(0, 5200, 1, -32), UDim2.new(0, 12, 0, 16), nil, true)
        list(reel, Enum.FillDirection.Horizontal, 12)
        local marker =
            frame("Marker", reelBox, UDim2.new(0, 2, 1, 0), UDim2.fromScale(0.5, 0), Theme.AMBER)
        marker.AnchorPoint = Vector2.new(0.5, 0)
        marker.ZIndex = 5

        local won =
            text("WonText", root, "", 28, Theme.DIM, Theme.DISPLAY, Enum.TextXAlignment.Center)
        won.Position = UDim2.new(0, 0, 0, 282)
        won.Size = UDim2.new(1, 0, 0, 40)

        -- Published odds — Roblox requires disclosure for paid random items
        local odds = frame("Odds", root, UDim2.new(0.56, -6, 0, 186), UDim2.new(0, 0, 0, 330))
        stroke(odds)
        pad(odds, 14)
        text("Caption", odds, "PUBLISHED ODDS", 10, Theme.DIM)
        local oddsList =
            frame("List", odds, UDim2.new(1, 0, 1, -22), UDim2.new(0, 0, 0, 22), nil, true)
        list(oddsList, nil, 6)
        for i, r in Rarities do
            local row = frame(r.name, oddsList, UDim2.new(1, 0, 0, 22), nil, nil, true)
            row.LayoutOrder = i
            local n = text("TierName", row, string.upper(r.name), 16, r.colour, Theme.DISPLAY)
            n.Size = UDim2.new(0, 120, 1, 0)
            local p = text("Pct", row, "", 12, Theme.INK)
            p.Position = UDim2.new(0, 124, 0, 0)
            p.Size = UDim2.new(0, 60, 1, 0)
            local barBg = frame(
                "BarBg",
                row,
                UDim2.new(1, -196, 0, 8),
                UDim2.new(0, 188, 0.5, -4),
                Color3.fromHex("1a1f26")
            )
            frame("Bar", barBg, UDim2.fromScale(0, 1), nil, r.colour)
        end

        local shelf = frame("Shelf", root, UDim2.new(0.44, -6, 0, 186), UDim2.new(0.56, 6, 0, 330))
        stroke(shelf)
        pad(shelf, 14)
        text("Caption", shelf, "DIRECT BUY · NO GAMBLE", 10, Theme.DIM)
        local items =
            frame("Items", shelf, UDim2.new(1, 0, 1, -22), UDim2.new(0, 0, 0, 22), nil, true)
        grid(items, UDim2.new(0.25, -6, 1, 0), 8)

        local btns =
            frame("Buttons", root, UDim2.new(1, 0, 0, 46), UDim2.new(0, 0, 1, -46), nil, true)
        list(btns, Enum.FillDirection.Horizontal, 10, Enum.HorizontalAlignment.Center)
        local balance =
            text("Balance", btns, "0 coins", 14, Theme.SOFT, Theme.MONO, Enum.TextXAlignment.Right)
        balance.Size = UDim2.new(0, 220, 1, 0)
        balance.LayoutOrder = 0
        button("Spin", btns, "SPIN", UDim2.new(0, 280, 1, 0)).LayoutOrder = 1
        local back = button("Close", btns, "BACK", UDim2.new(0, 140, 1, 0), RAISED, Theme.MUTED)
        back.LayoutOrder = 2
        stroke(back, Color3.fromHex("2b323c"))
        out.crate = g
    end

    ------------------------------------------------------------------ INVENTORY
    do
        local g, root = screen(parent :: Instance, "InventoryGui", 6, 0.06)
        pad(root, 26)
        header(root, "CASE FILE", "YOUR COLLECTION")
        local summary = text(
            "Summary",
            root,
            "0 owned · 0 coins",
            12,
            Theme.MUTED,
            Theme.MONO,
            Enum.TextXAlignment.Right
        )
        summary.Position = UDim2.new(0, 0, 0, 44)

        local scroll = scroller("Items", root, UDim2.new(1, 0, 1, -196), UDim2.new(0, 0, 0, 90))
        grid(scroll, UDim2.fromOffset(160, 190), 12)
        local card = frame("ItemTemplate", scroll, UDim2.fromOffset(160, 190))
        stroke(card)
        card.Visible = false
        local sw =
            frame("Swatch", card, UDim2.fromOffset(44, 44), UDim2.new(0.5, -22, 0, 18), Theme.DIM)
        sw.Rotation = 45
        local nm =
            text("ItemName", card, "ITEM", 18, Theme.INK, Theme.DISPLAY, Enum.TextXAlignment.Center)
        nm.Position = UDim2.new(0, 0, 0, 72)
        local rar = text("Rarity", card, "", 9, Theme.DIM, Theme.MONO, Enum.TextXAlignment.Center)
        rar.Position = UDim2.new(0, 0, 0, 98)
        local fx = text("Effect", card, "", 9, Theme.SOFT, Theme.MONO, Enum.TextXAlignment.Center)
        fx.Position = UDim2.new(0, 0, 0, 114)
        local select = Instance.new("TextButton")
        select.Name = "Select"
        select.Text = ""
        select.BackgroundTransparency = 1
        select.Size = UDim2.new(1, 0, 1, -Theme.TAP_MIN)
        select.Parent = card
        local eq = button("Equip", card, "EQUIP", UDim2.new(1, -16, 0, 36), RAISED, Theme.AMBER)
        eq.Position = UDim2.new(0, 8, 1, -42)
        stroke(eq, Color3.fromHex("2b323c"))

        local status = text("Status", root, "", 12, Theme.SOFT)
        status.Position = UDim2.new(0, 0, 1, -76)

        local btns = frame(
            "Buttons",
            root,
            UDim2.new(1, 0, 0, Theme.TAP_MIN),
            UDim2.new(0, 0, 1, -Theme.TAP_MIN),
            nil,
            true
        )
        list(btns, Enum.FillDirection.Horizontal, 10)
        local craft = button("Craft", btns, "CRAFT 5 → 1", UDim2.new(0, 260, 1, 0), RAISED, GREEN)
        craft.LayoutOrder = 1
        stroke(craft, GREEN)
        local reroll =
            button("Reroll", btns, "RE-ROLL EFFECT", UDim2.new(0, 280, 1, 0), RAISED, Theme.MUTED)
        reroll.LayoutOrder = 2
        stroke(reroll, Color3.fromHex("2b323c"))
        button("Close", btns, "BACK", UDim2.new(0, 140, 1, 0), RAISED, Theme.MUTED).LayoutOrder = 3
        out.inventory = g
    end

    ------------------------------------------------------------------ TRADE
    do
        local g, root = screen(parent :: Instance, "TradeGui", 7, 0.06)
        pad(root, 26)
        header(root, "ESCROWED SWAP", "TRADE")
        local note = text(
            "Note",
            root,
            "Any change to either table resets both locks.",
            12,
            Theme.MUTED,
            Theme.MONO,
            Enum.TextXAlignment.Right
        )
        note.Position = UDim2.new(0, 0, 0, 44)

        local function side(name: string, x: number, caption: string)
            local f = frame(
                name,
                root,
                UDim2.new(0.5, -7, 0, 196),
                UDim2.new(x, x == 0 and 0 or 7, 0, 86)
            )
            stroke(f)
            pad(f, 12)
            text("Caption", f, caption, 10, Theme.INK)
            local lock =
                text("Lock", f, "Editing", 11, Theme.MUTED, Theme.MONO, Enum.TextXAlignment.Right)
            lock.Size = UDim2.new(1, 0, 0, 16)
            local slots =
                frame("Slots", f, UDim2.new(1, 0, 0, 132), UDim2.new(0, 0, 0, 22), nil, true)
            grid(slots, UDim2.fromOffset(92, 62), 6)
            local val = text("Value", f, "Table value · 0", 12, Theme.MUTED)
            val.Position = UDim2.new(0, 0, 1, -18)
        end
        side("Mine", 0, "YOUR OFFER")
        side("Theirs", 0.5, "THEIR OFFER")

        local fair = frame("Fairness", root, UDim2.new(1, 0, 0, 62), UDim2.new(0, 0, 0, 292), SUNK)
        stroke(fair)
        pad(fair, 12)
        text("Caption", fair, "FAIRNESS", 10, Theme.DIM)
        local fl = text(
            "Label",
            fair,
            "Empty table",
            10,
            Theme.MUTED,
            Theme.MONO,
            Enum.TextXAlignment.Right
        )
        fl.Size = UDim2.new(1, 0, 0, 14)
        local track = frame(
            "Track",
            fair,
            UDim2.new(1, 0, 0, 10),
            UDim2.new(0, 0, 0, 22),
            Color3.fromHex("1a1f26")
        )
        local centre = frame(
            "Centre",
            track,
            UDim2.new(0, 2, 1, 0),
            UDim2.fromScale(0.5, 0),
            Color3.fromHex("3a4450")
        )
        centre.AnchorPoint = Vector2.new(0.5, 0)
        centre.ZIndex = 2
        frame("Fill", track, UDim2.new(0, 0, 1, 0), UDim2.fromScale(0.5, 0), GREEN)

        local btns = frame(
            "Buttons",
            root,
            UDim2.new(1, 0, 0, Theme.TAP_MIN),
            UDim2.new(0, 0, 0, 364),
            nil,
            true
        )
        list(btns, Enum.FillDirection.Horizontal, 10)
        local lockBtn =
            button("Lock", btns, "LOCK MY OFFER", UDim2.new(0.4, -7, 1, 0), Theme.CARD, Theme.CYAN)
        lockBtn.LayoutOrder = 1
        stroke(lockBtn, Theme.CYAN)
        button(
            "Confirm",
            btns,
            "CONFIRM TRADE",
            UDim2.new(0.4, -7, 1, 0),
            Color3.fromHex("2b323c"),
            BG
        ).LayoutOrder =
            2
        local cancel =
            button("Cancel", btns, "CANCEL", UDim2.new(0.2, -6, 1, 0), RAISED, Theme.MUTED)
        cancel.LayoutOrder = 3
        stroke(cancel, Color3.fromHex("2b323c"))

        local status = text("Status", root, "", 12, Theme.MUTED)
        status.Position = UDim2.new(0, 0, 0, 414)

        local poolBox =
            frame("Pool", root, UDim2.new(1, 0, 1, -440), UDim2.new(0, 0, 0, 440), nil, true)
        text("Caption", poolBox, "YOUR INVENTORY — TAP TO PUT ON THE TABLE", 10, Theme.DIM)
        local pool = scroller("Items", poolBox, UDim2.new(1, 0, 1, -20), UDim2.new(0, 0, 0, 20))
        grid(pool, UDim2.fromOffset(110, 74), 8)
        out.trade = g
    end

    return out
end
