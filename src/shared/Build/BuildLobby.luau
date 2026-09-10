--[[
  COLD CASE · LobbyHud builder — the onboarding surfaces (Handbook §02).
  Placeholder layout in the HUD's visual language until the lobby, results
  and crate screens are designed. LobbyController builds it at runtime.

  LobbyHud (ScreenGui)
    Vote     (Frame)      Title, Options (BlackwoodManor/RustedPier/CityArchive TextButtons)
    Locker   (Frame)      Title, Balance, Open (TextButton)
    Results  (Frame)      Title, Reveal, Reward, NearMiss
    Hint     (TextLabel)  ghost prompt
    Toast    (TextLabel)  short server notices
]]
local Theme = require(script.Parent.Parent.Theme)
local Config = require(script.Parent.Parent.Config)

local MAP_LABEL = {
    BlackwoodManor = "BLACKWOOD MANOR",
    RustedPier = "RUSTED PIER",
    CityArchive = "CITY ARCHIVE",
}

local function frame(
    name: string,
    parent: Instance,
    size: UDim2,
    pos: UDim2,
    anchor: Vector2
): Frame
    local f = Instance.new("Frame")
    f.Name = name
    f.Size = size
    f.Position = pos
    f.AnchorPoint = anchor
    f.BackgroundColor3 = Theme.GROUND
    f.BackgroundTransparency = 0.18
    f.BorderSizePixel = 0
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 5)
    c.Parent = f
    local s = Instance.new("UIStroke")
    s.Color = Theme.STROKE
    s.Parent = f
    f.Parent = parent
    return f
end

local function text(
    class: string,
    name: string,
    parent: Instance,
    value: string,
    size: number,
    font: Font?
): any
    local l = Instance.new(class)
    l.Name = name
    l.Text = value
    l.TextSize = size
    l.FontFace = font or Theme.MONO
    l.TextColor3 = Theme.INK
    l.BackgroundTransparency = 1
    l.Parent = parent
    return l
end

local function button(name: string, parent: Instance, value: string): TextButton
    local b = text("TextButton", name, parent, value, 14, Theme.MONO) :: TextButton
    b.BackgroundColor3 = Theme.PANEL
    b.BackgroundTransparency = 0
    b.AutoButtonColor = true
    b.Size = UDim2.new(0, 124, 0, Theme.TAP_MIN)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 4)
    c.Parent = b
    local s = Instance.new("UIStroke")
    s.Name = "Stroke"
    s.Color = Theme.STROKE
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent = b
    return b
end

return function(parent: Instance?): ScreenGui
    parent = parent or game:GetService("StarterGui")
    local old = (parent :: Instance):FindFirstChild("LobbyHud")
    if old then
        old:Destroy()
    end

    local gui = Instance.new("ScreenGui")
    gui.Name = "LobbyHud"
    gui.IgnoreGuiInset = true
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 2

    ---------------------------------------------------------------- Vote
    local vote =
        frame("Vote", gui, UDim2.new(0, 420, 0, 96), UDim2.new(0.5, 0, 0, 84), Vector2.new(0.5, 0))
    local vt = text("TextLabel", "Title", vote, "VOTE THE SCENE", 10)
    vt.TextColor3 = Theme.DIM
    vt.Size = UDim2.new(1, 0, 0, 24)
    local options = Instance.new("Frame")
    options.Name = "Options"
    options.BackgroundTransparency = 1
    options.Position = UDim2.new(0, 0, 0, 30)
    options.Size = UDim2.new(1, 0, 0, Theme.TAP_MIN)
    options.Parent = vote
    local ol = Instance.new("UIListLayout")
    ol.FillDirection = Enum.FillDirection.Horizontal
    ol.HorizontalAlignment = Enum.HorizontalAlignment.Center
    ol.Padding = UDim.new(0, 8)
    ol.SortOrder = Enum.SortOrder.LayoutOrder
    ol.Parent = options
    for i, mapName in Config.MAPS do
        local b = button(mapName, options, MAP_LABEL[mapName] or mapName)
        b.TextSize = 12
        b.LayoutOrder = i
    end

    ---------------------------------------------------------------- Locker
    local locker =
        frame("Locker", gui, UDim2.new(0, 190, 0, 104), UDim2.new(1, -14, 0, 84), Vector2.new(1, 0))
    local lt = text("TextLabel", "Title", locker, "THE LOCKER", 10)
    lt.TextColor3 = Theme.DIM
    lt.Size = UDim2.new(1, 0, 0, 24)
    local bal = text(
        "TextLabel",
        "Balance",
        locker,
        ("0 / %d"):format(Config.CRATE_COST),
        22,
        Theme.DISPLAY
    )
    bal.Position = UDim2.new(0, 0, 0, 20)
    bal.Size = UDim2.new(1, 0, 0, 28)
    local open = button("Open", locker, ("OPEN · %d"):format(Config.CRATE_COST))
    open.AnchorPoint = Vector2.new(0.5, 0)
    open.Position = UDim2.new(0.5, 0, 0, 52)
    open.Size = UDim2.new(1, -20, 0, Theme.TAP_MIN)

    ---------------------------------------------------------------- Results
    local results = frame(
        "Results",
        gui,
        UDim2.new(0, 520, 0, 250),
        UDim2.fromScale(0.5, 0.5),
        Vector2.new(0.5, 0.5)
    )
    results.BackgroundColor3 = Theme.CARD
    results.BackgroundTransparency = 0
    results.Visible = false
    local rows = {
        { "Title", "ROUND OVER", 12, Theme.MONO, 40 },
        { "Reveal", "", 40, Theme.DISPLAY_HEAVY, 76 },
        { "Reward", "", 16, Theme.MONO, 150 },
        { "NearMiss", "", 14, Theme.MONO, 186 },
    }
    for _, r in rows do
        local l = text("TextLabel", r[1], results, r[2], r[3], r[4])
        l.Position = UDim2.new(0, 20, 0, r[5])
        l.Size = UDim2.new(1, -40, 0, r[3] + 16)
        l.TextWrapped = true
    end
    results.Title.TextColor3 = Theme.DIM
    results.NearMiss.TextColor3 = Theme.SOFT

    ---------------------------------------------------------------- Hint + Toast
    local hint = text("TextLabel", "Hint", gui, "", 18)
    hint.AnchorPoint = Vector2.new(0.5, 1)
    hint.Position = UDim2.new(0.5, 0, 1, -140)
    hint.Size = UDim2.new(0, 520, 0, 30)
    hint.TextColor3 = Theme.SOFT
    hint.TextStrokeTransparency = 0.8
    hint.TextTransparency = 1

    local toast = text("TextLabel", "Toast", gui, "", 16)
    toast.AnchorPoint = Vector2.new(0.5, 0)
    toast.Position = UDim2.new(0.5, 0, 0, 196)
    toast.Size = UDim2.new(0, 560, 0, 28)
    toast.TextStrokeTransparency = 0.7
    toast.TextTransparency = 1

    gui.Parent = parent
    return gui
end
