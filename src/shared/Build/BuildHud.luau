--!strict
--[[
  COLD CASE · RoundHud builder (Production Handbook §01)
  HudController calls this at runtime when PlayerGui has no RoundHud, so a
  fresh build needs no manual Studio step. To bake it into StarterGui instead:
    require(game.ReplicatedStorage.Shared.Build.BuildHud)()

  RoundHud (ScreenGui)  IgnoreGuiInset, ResetOnSpawn = false
    Top          (Frame)  StateBox/TimerBox/AliveBox/CoinsBox, each Caption + Value
    RoleTag      (Frame)  RoleName            -- top right, border = role colour
    RoleCard     (Frame)  full-screen dim     -- Card, RoleName, Brief
    EventBanner  (Frame)  Label               -- no background
    Evidence     (Frame)  Title, Line1..Line4 -- bottom left, newest on top
    Action       (Frame)  Weapon, Prompt      -- bottom right
]]
local Theme = require(script.Parent.Parent.Theme)

local function panel(
    name: string,
    parent: Instance,
    size: UDim2,
    pos: UDim2,
    anchor: Vector2?
): Frame
    local f = Instance.new("Frame")
    f.Name = name
    f.Size = size
    f.Position = pos
    f.AnchorPoint = anchor or Vector2.zero
    f.BackgroundColor3 = Theme.GROUND
    f.BackgroundTransparency = 0.18
    f.BorderSizePixel = 0
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 5)
    c.Parent = f
    local s = Instance.new("UIStroke")
    s.Name = "Stroke"
    s.Color = Theme.STROKE
    s.Thickness = 1
    s.Parent = f
    f.Parent = parent
    return f
end

local function label(
    name: string,
    parent: Instance,
    text: string,
    size: number,
    colour: Color3?,
    font: Font?
): TextLabel
    local l = Instance.new("TextLabel")
    l.Name = name
    l.Text = text
    l.FontFace = font or Theme.MONO
    l.TextSize = size
    l.TextColor3 = colour or Theme.INK
    l.BackgroundTransparency = 1
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Size = UDim2.fromScale(1, 1)
    l.Parent = parent
    return l
end

local function pad(parent: Instance, l: number, t: number, r: number?, b: number?)
    local p = Instance.new("UIPadding")
    p.PaddingLeft = UDim.new(0, l)
    p.PaddingTop = UDim.new(0, t)
    p.PaddingRight = UDim.new(0, r or 0)
    p.PaddingBottom = UDim.new(0, b or 0)
    p.Parent = parent
end

return function(parent: Instance?): ScreenGui
    parent = parent or game:GetService("StarterGui")
    local old = (parent :: Instance):FindFirstChild("RoundHud")
    if old then
        old:Destroy()
    end

    local gui = Instance.new("ScreenGui")
    gui.Name = "RoundHud"
    gui.IgnoreGuiInset = true
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.DisplayOrder = 1

    ---------------------------------------------------------------- Top
    local top = Instance.new("Frame")
    top.Name = "Top"
    top.AnchorPoint = Vector2.new(0.5, 0)
    top.Position = UDim2.new(0.5, 0, 0, 14)
    top.Size = UDim2.new(0, 420, 0, 58)
    top.BackgroundTransparency = 1
    top.Parent = gui

    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.Padding = UDim.new(0, 10)
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = top

    local function stat(
        order: number,
        name: string,
        caption: string,
        value: string,
        colour: Color3,
        size: number
    )
        local f = panel(name .. "Box", top, UDim2.new(0.25, -8, 1, 0), UDim2.new())
        f.LayoutOrder = order
        pad(f, 10, 6, 6)
        local cap = label("Caption", f, caption, 10, Theme.DIM)
        cap.Size = UDim2.new(1, 0, 0, 12)
        local val = label("Value", f, value, size, colour, Theme.DISPLAY)
        val.Position = UDim2.new(0, 0, 0, 13)
        val.Size = UDim2.new(1, 0, 0, 36)
        val.TextScaled = true
        local limit = Instance.new("UITextSizeConstraint")
        limit.MaxTextSize = size
        limit.Parent = val
    end
    stat(1, "State", "ROUND", "LOBBY", Theme.MUTED, 22)
    stat(2, "Timer", "TIME", "—", Theme.INK, 34) -- the only element that changes colour mid-round
    stat(3, "Alive", "ALIVE", "—", Theme.INK, 26)
    stat(4, "Coins", "COINS", "0", Theme.INK, 26)

    ---------------------------------------------------------------- RoleTag
    local roleTag =
        panel("RoleTag", gui, UDim2.new(0, 190, 0, 58), UDim2.new(1, -14, 0, 14), Vector2.new(1, 0))
    pad(roleTag, 12, 6, 12)
    local rtCap = label("Caption", roleTag, "YOUR ROLE", 10, Theme.DIM)
    rtCap.Size = UDim2.new(1, 0, 0, 12)
    rtCap.TextXAlignment = Enum.TextXAlignment.Right
    local rtName = label("RoleName", roleTag, "—", 26, Theme.MUTED, Theme.DISPLAY)
    rtName.Position = UDim2.new(0, 0, 0, 13)
    rtName.Size = UDim2.new(1, 0, 0, 34)
    rtName.TextXAlignment = Enum.TextXAlignment.Right

    ---------------------------------------------------------------- RoleCard
    local dim = Instance.new("Frame")
    dim.Name = "RoleCard"
    dim.Size = UDim2.fromScale(1, 1)
    dim.BackgroundColor3 = Color3.new(0, 0, 0)
    dim.BackgroundTransparency = 0.6
    dim.BorderSizePixel = 0
    dim.Visible = false
    dim.ZIndex = 10
    dim.Parent = gui

    local card = panel(
        "Card",
        dim,
        UDim2.new(0, 520, 0, 300),
        UDim2.fromScale(0.5, 0.5),
        Vector2.new(0.5, 0.5)
    )
    card.BackgroundColor3 = Theme.CARD
    card.BackgroundTransparency = 0
    card.ZIndex = 11
    local sizeLimit = Instance.new("UISizeConstraint")
    sizeLimit.MaxSize = Vector2.new(520, 300)
    sizeLimit.Parent = card

    local youAre = label("YouAre", card, "YOU ARE", 11, Theme.DIM)
    youAre.TextXAlignment = Enum.TextXAlignment.Center
    youAre.Position = UDim2.new(0, 0, 0, 44)
    youAre.Size = UDim2.new(1, 0, 0, 16)
    youAre.ZIndex = 12

    local cardName =
        label("RoleName", dim, "INNOCENT", 76, Theme.ROLE.innocent, Theme.DISPLAY_HEAVY)
    cardName.TextXAlignment = Enum.TextXAlignment.Center
    cardName.AnchorPoint = Vector2.new(0.5, 0.5)
    cardName.Position = UDim2.fromScale(0.5, 0.46)
    cardName.Size = UDim2.new(0, 500, 0, 90)
    cardName.ZIndex = 12

    local brief = label("Brief", dim, "", 15, Theme.SOFT)
    brief.TextXAlignment = Enum.TextXAlignment.Center
    brief.AnchorPoint = Vector2.new(0.5, 0)
    brief.Position = UDim2.new(0.5, 0, 0.5, 40)
    brief.Size = UDim2.new(0, 420, 0, 60)
    brief.TextWrapped = true
    brief.ZIndex = 12

    ---------------------------------------------------------------- EventBanner
    local banner = Instance.new("Frame")
    banner.Name = "EventBanner"
    banner.AnchorPoint = Vector2.new(0.5, 0)
    banner.Position = UDim2.new(0.5, 0, 0, 100)
    banner.Size = UDim2.new(0, 600, 0, 46)
    banner.BackgroundTransparency = 1
    banner.Visible = false
    banner.Parent = gui
    local bl = label("Label", banner, "", 34, Theme.CYAN, Theme.DISPLAY)
    bl.TextXAlignment = Enum.TextXAlignment.Center
    bl.TextStrokeTransparency = 0.7

    ---------------------------------------------------------------- Evidence
    local ev = panel(
        "Evidence",
        gui,
        UDim2.new(0, 340, 0, 150),
        UDim2.new(0, 16, 1, -16),
        Vector2.new(0, 1)
    )
    pad(ev, 13, 11, 11)
    local evList = Instance.new("UIListLayout")
    evList.Padding = UDim.new(0, 5)
    evList.SortOrder = Enum.SortOrder.LayoutOrder
    evList.Parent = ev

    local evTitle = label("Title", ev, "EVIDENCE LOG", 10, Theme.DIM)
    evTitle.Size = UDim2.new(1, 0, 0, 14)
    evTitle.LayoutOrder = 0
    for i = 1, 4 do
        local line = label("Line" .. i, ev, "", 12, Theme.BODY)
        line.Size = UDim2.new(1, 0, 0, 26)
        line.TextWrapped = true
        line.TextYAlignment = Enum.TextYAlignment.Center
        line.LayoutOrder = i
        pad(line, 9, 0)
        local bar = Instance.new("Frame")
        bar.Name = "Bar"
        bar.Size = UDim2.new(0, 2, 1, 0)
        bar.Position = UDim2.new(0, -9, 0, 0)
        bar.BorderSizePixel = 0
        bar.BackgroundColor3 = Theme.CLUE.cold
        bar.Visible = false
        bar.Parent = line
    end

    ---------------------------------------------------------------- Action
    local act =
        panel("Action", gui, UDim2.new(0, 260, 0, 86), UDim2.new(1, -16, 1, -16), Vector2.new(1, 1))
    pad(act, 14, 10, 10)
    local wCap = label("WeaponCaption", act, "EQUIPPED", 9, Theme.DIM)
    wCap.Size = UDim2.new(1, 0, 0, 12)
    local weapon = label("Weapon", act, "—", 22, Theme.MUTED, Theme.DISPLAY)
    weapon.Position = UDim2.new(0, 0, 0, 14)
    weapon.Size = UDim2.new(1, 0, 0, 28)
    local prompt = label("Prompt", act, "—", 13, Theme.INK)
    prompt.Position = UDim2.new(0, 0, 0, 46)
    prompt.Size = UDim2.new(1, 0, 0, 22)

    gui.Parent = parent
    return gui
end
