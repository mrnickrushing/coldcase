--[[
  COLD CASE · lobby dressing. A precinct room around the lobby spawn: brick
  walls, warm lamps, the case board, and furniture from ServerStorage.Props
  when it exists. Bootstrap runs this on server start; it rebuilds cleanly.
  The floor and spawn themselves come from default.project.json.
]]
local ServerStorage = game:GetService("ServerStorage")
local Theme = require(game.ReplicatedStorage.Shared.Theme)

local HEIGHT = 18
local BRICK = Color3.fromHex("cf9a6a")
local LAMP = Color3.fromHex("ffe3b0")

-- { template, x, z, facing } relative to the floor centre; the front of the
-- prop looks along `facing`
local PROPS = {
    -- -Z wall: library and game-room wall. Spaced by real footprints so nothing
    -- clips (the clock and television once sat 2 studs apart and overlapped).
    { "Bookshelf", -46, -57.5, Vector3.zAxis },
    { "GrandfatherClock", -36, -58.5, Vector3.zAxis },
    { "Television", -22, -57.5, Vector3.zAxis },
    { "VendingMachine", 14, -57.5, Vector3.zAxis },
    { "Arcade", 24, -57.5, Vector3.zAxis },
    { "Bookshelf", 40, -57.5, Vector3.zAxis },
    -- Media corner: the red couch sits out in the room facing the television,
    -- instead of alone against a blank wall.
    { "SofaRed", -22, -40, -Vector3.zAxis },
    -- +Z fireplace lounge: the sofa faces the room with the fire as its
    -- backdrop, and an armchair at each end is turned in toward the group -
    -- a conversation set on the rug, not furniture pushed to the walls.
    { "Fireplace", 0, 58, -Vector3.zAxis },
    { "Sofa", 0, 44, -Vector3.zAxis },
    { "Armchair", -11, 40, Vector3.new(0.878, 0, -0.479) },
    { "Armchair", 11, 40, Vector3.new(-0.878, 0, -0.479) },
    -- +X study corner
    { "FilingCabinet", 57.5, -30, -Vector3.xAxis },
    { "FilingCabinet", 57.5, -26.5, -Vector3.xAxis },
    { "WritingDesk", 46, 18, -Vector3.xAxis },
    { "Globe", 50, 32, -Vector3.xAxis },
    { "Bookshelf", 57.5, -50, -Vector3.xAxis },
    -- -X wall
    { "CrateStack", -57.5, 0, -Vector3.xAxis },
    -- corner plants
    { "Plant", -52, -52, Vector3.xAxis },
    { "Plant", 52, -52, -Vector3.xAxis },
    { "Plant", -52, 52, Vector3.xAxis },
}

local function block(
    name: string,
    parent: Instance,
    size: Vector3,
    position: Vector3,
    colour: Color3,
    material: Enum.Material
): Part
    local p = Instance.new("Part")
    p.Name = name
    p.Anchored = true
    p.Size = size
    p.Position = position
    p.Color = colour
    p.Material = material
    p.TopSurface = Enum.SurfaceType.Smooth
    p.BottomSurface = Enum.SurfaceType.Smooth
    p.Parent = parent
    return p
end

local function caseBoard(parent: Instance, position: Vector3)
    local board = block(
        "CaseBoard",
        parent,
        Vector3.new(24, 10, 0.4),
        position,
        Color3.fromHex("2b2118"),
        Enum.Material.Wood
    )
    local gui = Instance.new("SurfaceGui")
    gui.Face = Enum.NormalId.Back -- +Z, into the room
    gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
    gui.PixelsPerStud = 40
    gui.LightInfluence = 1
    gui.Parent = board

    local title = Instance.new("TextLabel")
    title.BackgroundTransparency = 1
    title.Size = UDim2.fromScale(1, 0.55)
    title.Position = UDim2.fromScale(0, 0.1)
    title.Text = "COLD CASE"
    title.FontFace = Theme.DISPLAY
    title.TextScaled = true
    title.TextColor3 = Theme.INK
    title.Parent = gui

    local line = Instance.new("TextLabel")
    line.BackgroundTransparency = 1
    line.Size = UDim2.fromScale(0.9, 0.18)
    line.Position = UDim2.fromScale(0.05, 0.68)
    line.Text = "One of you has a knife. Nobody knows who."
    line.FontFace = Theme.MONO
    line.TextScaled = true
    line.TextColor3 = Theme.DANGER
    line.Parent = gui
end

return function()
    local lobby = workspace:FindFirstChild("Lobby")
    local floor = lobby and lobby:FindFirstChild("LobbyFloor")
    if not (floor and floor:IsA("BasePart")) then
        return
    end
    local old = (lobby :: Instance):FindFirstChild("Dressing")
    if old then
        old:Destroy()
    end
    local dressing = Instance.new("Folder")
    dressing.Name = "Dressing"

    floor.Material = Enum.Material.WoodPlanks
    floor.Color = Color3.fromHex("a9855c")
    local top = floor.Position + Vector3.new(0, floor.Size.Y / 2, 0)
    local half = floor.Size.X / 2

    local wallY = top.Y + HEIGHT / 2
    for i, spec in
        {
            { Vector3.new(floor.Size.X + 4, HEIGHT, 2), Vector3.new(0, 0, -half - 1) },
            { Vector3.new(floor.Size.X + 4, HEIGHT, 2), Vector3.new(0, 0, half + 1) },
            { Vector3.new(2, HEIGHT, floor.Size.Z), Vector3.new(-half - 1, 0, 0) },
            { Vector3.new(2, HEIGHT, floor.Size.Z), Vector3.new(half + 1, 0, 0) },
        }
    do
        local offset = spec[2]
        block(
            ("Wall_%d"):format(i),
            dressing,
            spec[1],
            Vector3.new(top.X + offset.X, wallY, top.Z + offset.Z),
            BRICK,
            Enum.Material.Brick
        )
    end

    for _, corner in { { -25, -25 }, { 25, -25 }, { -25, 25 }, { 25, 25 } } do
        local lamp = block(
            "Lamp",
            dressing,
            Vector3.new(1.4, 0.7, 1.4),
            Vector3.new(top.X + corner[1], top.Y + HEIGHT - 3, top.Z + corner[2]),
            LAMP,
            Enum.Material.Neon
        )
        lamp.CanCollide = false
        lamp.CanQuery = false
        lamp.CastShadow = false
        local light = Instance.new("PointLight")
        light.Color = LAMP
        light.Range = 48
        light.Brightness = 2
        light.Shadows = true
        light.Parent = lamp
    end

    caseBoard(dressing, Vector3.new(top.X, top.Y + 9, top.Z - half + 0.3))

    -- A floor of laid panels rather than one flat sheet, and a ceiling to
    -- close the room in
    local PANEL = 20
    for x = -half + PANEL / 2, half - PANEL / 2, PANEL do
        for z = -half + PANEL / 2, half - PANEL / 2, PANEL do
            local seamA = block(
                "FloorSeam",
                dressing,
                Vector3.new(PANEL, 0.08, 0.6),
                Vector3.new(top.X + x, top.Y + 0.04, top.Z + z + PANEL / 2),
                Color3.fromHex("6b5740"),
                Enum.Material.SmoothPlastic
            )
            local seamB = block(
                "FloorSeam",
                dressing,
                Vector3.new(0.6, 0.08, PANEL),
                Vector3.new(top.X + x + PANEL / 2, top.Y + 0.04, top.Z + z),
                Color3.fromHex("6b5740"),
                Enum.Material.SmoothPlastic
            )
            local inlay = block(
                "FloorInlay",
                dressing,
                Vector3.new(PANEL - 6, 0.06, PANEL - 6),
                Vector3.new(top.X + x, top.Y + 0.03, top.Z + z),
                Color3.fromHex("9d8259"),
                Enum.Material.SmoothPlastic
            )
            for _, piece in { seamA, seamB, inlay } do
                piece.CanCollide = false
                piece.CanQuery = false
                piece.CastShadow = false
            end
        end
    end
    local ceiling = block(
        "Ceiling",
        dressing,
        Vector3.new(floor.Size.X + 4, 0.6, floor.Size.Z + 4),
        Vector3.new(top.X, top.Y + HEIGHT, top.Z),
        Color3.fromHex("f2efe6"),
        Enum.Material.SmoothPlastic
    )
    ceiling.CanQuery = false

    -- A rug in front of the fireplace
    for _, layer in
        {
            { Vector3.new(26, 0.1, 16), 0.05, Color3.fromHex("8a2a2a") },
            { Vector3.new(24.8, 0.14, 14.8), 0.07, Color3.fromHex("b03a3a") },
        }
    do
        local rug = block(
            "Rug",
            dressing,
            layer[1],
            Vector3.new(top.X, top.Y + layer[2], top.Z + 46),
            layer[3],
            Enum.Material.Fabric
        )
        rug.CanCollide = false
        rug.CanQuery = false
    end

    local templates = ServerStorage:FindFirstChild("Props")
    for _, spec in PROPS do
        local template = templates and templates:FindFirstChild(spec[1])
        if template and template:IsA("Model") then
            local prop = template:Clone()
            for _, d in prop:GetDescendants() do
                if d:IsA("LuaSourceContainer") then
                    d:Destroy()
                elseif d:IsA("BasePart") then
                    d.Anchored = true
                end
            end
            local size = prop:GetExtentsSize()
            local at = Vector3.new(top.X + spec[2], top.Y + size.Y / 2, top.Z + spec[3])
            prop:PivotTo(CFrame.lookAt(at, at + spec[4]))
            prop.Parent = dressing
        end
    end

    dressing.Parent = lobby
end
