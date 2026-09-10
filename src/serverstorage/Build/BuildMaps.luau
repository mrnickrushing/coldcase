--[[
  COLD CASE · map blockout builder
  Bootstrap runs this automatically when ServerStorage.Maps is missing, so a
  fresh `rojo build` is playable. It can also be run from the command bar:
    require(game.ServerStorage.Build.BuildMaps)({ force = true })
  Generates all three maps as Models in ServerStorage.Maps with walls, floor,
  tagged SpawnPoints, CoinNodes and LockdownDoors, per-map materials, and
  lamps tagged MapLight (EventService turns them off for Lights Out), and
  furniture from ServerStorage.Props along the outer walls when it exists.
  Coordinates match the Map Blockouts canvas and its OBJ exports.
]]
local MAPS = {
    BlackwoodManor = {
        floor = Color3.fromHex("3b2a1f"),
        floorMaterial = Enum.Material.WoodPlanks,
        wall = Color3.fromHex("5a4038"),
        wallMaterial = Enum.Material.Plaster,
        outer = Color3.fromHex("3a3230"),
        outerMaterial = Enum.Material.Brick,
        lamp = Color3.fromHex("ffc27a"),
        props = { "Bookshelf", "Armchair", "GrandfatherClock" },
        height = 26,
        walls = {
            { 0, 0, 960, 14 },
            { 0, 586, 960, 14 },
            { 0, 0, 14, 600 },
            { 946, 0, 14, 600 },
            { 224, 14, 14, 178 },
            { 224, 262, 14, 196 },
            { 380, 120, 206, 14 },
            { 380, 120, 14, 178 },
            { 560, 300, 14, 200 },
            { 560, 300, 246, 14 },
            { 700, 14, 14, 158 },
            { 238, 458, 196, 14 },
            { 760, 440, 14, 146 },
            { 60, 300, 120, 14 },
        },
        spawns = {
            { 110, 90 },
            { 330, 70 },
            { 500, 60 },
            { 850, 90 },
            { 120, 520 },
            { 400, 540 },
            { 680, 540 },
            { 880, 480 },
            { 300, 220 },
            { 640, 180 },
        },
        coins = {
            { 80, 180 },
            { 300, 120 },
            { 470, 240 },
            { 640, 90 },
            { 820, 200 },
            { 160, 400 },
            { 330, 330 },
            { 500, 430 },
            { 700, 300 },
            { 880, 360 },
            { 250, 540 },
            { 430, 480 },
            { 620, 470 },
            { 800, 540 },
            { 140, 260 },
            { 900, 120 },
        },
        doors = {
            { 224, 192, 14, 70 },
            { 380, 298, 14, 60 },
            { 560, 440, 14, 60 },
            { 700, 172, 14, 60 },
        },
    },
    RustedPier = {
        floor = Color3.fromHex("4a4640"),
        floorMaterial = Enum.Material.WoodPlanks,
        wall = Color3.fromHex("3e4a52"),
        wallMaterial = Enum.Material.CorrodedMetal,
        outer = Color3.fromHex("2f3438"),
        outerMaterial = Enum.Material.Concrete,
        lamp = Color3.fromHex("ffb35c"),
        props = { "CrateStack", "Barrel" },
        lampPosts = true,
        height = 20,
        walls = {
            { 0, 0, 960, 14 },
            { 0, 586, 960, 14 },
            { 0, 0, 14, 600 },
            { 946, 0, 14, 600 },
            { 140, 120, 180, 16 },
            { 640, 120, 180, 16 },
            { 140, 464, 180, 16 },
            { 640, 464, 180, 16 },
            { 452, 200, 16, 200 },
            { 300, 290, 120, 16 },
            { 540, 290, 120, 16 },
        },
        spawns = {
            { 70, 60 },
            { 480, 50 },
            { 900, 60 },
            { 70, 540 },
            { 480, 550 },
            { 900, 540 },
            { 240, 300 },
            { 720, 300 },
            { 400, 170 },
            { 560, 430 },
        },
        coins = {
            { 200, 170 },
            { 700, 170 },
            { 200, 510 },
            { 700, 510 },
            { 460, 110 },
            { 460, 500 },
            { 80, 300 },
            { 880, 300 },
            { 350, 250 },
            { 610, 250 },
            { 350, 360 },
            { 610, 360 },
            { 130, 420 },
            { 830, 180 },
        },
        doors = {},
    },
    CityArchive = {
        floor = Color3.fromHex("4a4843"),
        floorMaterial = Enum.Material.CeramicTiles,
        wall = Color3.fromHex("5a4630"),
        wallMaterial = Enum.Material.WoodPlanks,
        outer = Color3.fromHex("55595c"),
        outerMaterial = Enum.Material.Concrete,
        lamp = Color3.fromHex("dfe8ff"),
        props = { "FilingCabinet", "Bookshelf" },
        height = 22,
        walls = {
            { 0, 0, 960, 14 },
            { 0, 586, 960, 14 },
            { 0, 0, 14, 600 },
            { 946, 0, 14, 600 },
            { 120, 80, 16, 180 },
            { 240, 80, 16, 180 },
            { 360, 80, 16, 180 },
            { 480, 80, 16, 180 },
            { 600, 80, 16, 180 },
            { 720, 80, 16, 180 },
            { 840, 80, 16, 180 },
            { 180, 340, 16, 180 },
            { 300, 340, 16, 180 },
            { 420, 340, 16, 180 },
            { 540, 340, 16, 180 },
            { 660, 340, 16, 180 },
            { 780, 340, 16, 180 },
        },
        spawns = {
            { 60, 40 },
            { 480, 40 },
            { 900, 40 },
            { 60, 560 },
            { 480, 560 },
            { 900, 560 },
            { 60, 300 },
            { 900, 300 },
            { 300, 300 },
            { 660, 300 },
        },
        coins = {
            { 180, 120 },
            { 300, 200 },
            { 420, 120 },
            { 540, 200 },
            { 660, 120 },
            { 780, 200 },
            { 240, 400 },
            { 360, 480 },
            { 480, 400 },
            { 600, 480 },
            { 720, 400 },
            { 840, 480 },
            { 60, 180 },
            { 900, 180 },
            { 60, 460 },
            { 900, 460 },
            { 180, 300 },
            { 760, 300 },
        },
        doors = {
            { 136, 260, 120, 14 },
            { 616, 260, 120, 14 },
            { 196, 320, 120, 14 },
            { 676, 320, 120, 14 },
        },
    },
}

local W, D = 960, 600
local LAMP_SPACING = 150
local PROP_CLEARANCE = 16 -- studs kept clear around every spawn and coin

-- The inner face of each outer wall, in plan coordinates
local SIDES = {
    { origin = Vector2.new(14, 14), along = Vector2.new(1, 0), inward = Vector2.new(0, 1) },
    { origin = Vector2.new(14, 586), along = Vector2.new(1, 0), inward = Vector2.new(0, -1) },
    { origin = Vector2.new(14, 14), along = Vector2.new(0, 1), inward = Vector2.new(1, 0) },
    { origin = Vector2.new(946, 14), along = Vector2.new(0, 1), inward = Vector2.new(-1, 0) },
}

local function part(name, parent, size, pos, colour, material: Enum.Material?)
    local p = Instance.new("Part")
    p.Name = name
    p.Size = size
    p.Position = pos
    p.Color = colour
    p.Anchored = true
    p.TopSurface = Enum.SurfaceType.Smooth
    p.BottomSurface = Enum.SurfaceType.Smooth
    p.Material = material or Enum.Material.SmoothPlastic
    p.Parent = parent
    return p
end

-- Blockout rect (x, y, w, h from the top-left of a 960×600 plan) to a centred
-- part position at height h/2
local function rectCentre(r, h)
    return Vector3.new(r[1] + r[3] / 2 - W / 2, h / 2, r[2] + r[4] / 2 - D / 2)
end

local function insideAny(rects, x: number, z: number, margin: number): boolean
    for _, r in rects do
        if
            x >= r[1] - margin
            and x <= r[1] + r[3] + margin
            and z >= r[2] - margin
            and z <= r[2] + r[4] + margin
        then
            return true
        end
    end
    return false
end

-- A prop footprint may not touch an inner wall or a door, and keeps
-- PROP_CLEARANCE from spawns and coins, so furniture never changes a route
local function blocked(def, x0: number, z0: number, x1: number, z1: number): boolean
    local m = 4
    local function overlaps(r)
        return x0 - m < r[1] + r[3] and x1 + m > r[1] and z0 - m < r[2] + r[4] and z1 + m > r[2]
    end
    for i, r in def.walls do
        if i > 4 and overlaps(r) then
            return true
        end
    end
    for _, r in def.doors do
        if overlaps(r) then
            return true
        end
    end
    for _, points in { def.spawns, def.coins } do
        for _, p in points do
            local dx = math.max(x0 - p[1], 0, p[1] - x1)
            local dz = math.max(z0 - p[2], 0, p[2] - z1)
            if math.sqrt(dx * dx + dz * dz) < PROP_CLEARANCE then
                return true
            end
        end
    end
    return false
end

-- Furniture against the outer walls, backs to the wall. Templates live in
-- ServerStorage.Props (not in the repo): Models whose pivot is the bounding
-- box centre, front facing -Z, width along X. Missing templates are skipped.
local function dress(model: Model, def, seed: number)
    local folder = game:GetService("ServerStorage"):FindFirstChild("Props")
    if not folder or not def.props then
        return
    end
    local rng = Random.new(seed)
    for _, side in SIDES do
        local length = if side.along.X ~= 0 then W - 28 else D - 28
        local t = rng:NextNumber(6, 30)
        while t < length - 6 do
            local template = folder:FindFirstChild(def.props[rng:NextInteger(1, #def.props)])
            if not (template and template:IsA("Model")) then
                t += 40
                continue
            end
            local size = template:GetExtentsSize()
            local a = side.origin + side.along * t
            local b = a + side.along * size.X + side.inward * (size.Z + 0.5)
            local x0, x1 = math.min(a.X, b.X), math.max(a.X, b.X)
            local z0, z1 = math.min(a.Y, b.Y), math.max(a.Y, b.Y)
            if not blocked(def, x0, z0, x1, z1) then
                local prop = template:Clone()
                for _, d in prop:GetDescendants() do
                    if d:IsA("LuaSourceContainer") then
                        d:Destroy() -- set dressing never runs code
                    elseif d:IsA("BasePart") then
                        d.Anchored = true
                    end
                end
                local centre = (a + b) / 2
                local world = Vector3.new(centre.X - W / 2, size.Y / 2, centre.Y - D / 2)
                local facing = Vector3.new(side.inward.X, 0, side.inward.Y)
                prop:PivotTo(CFrame.lookAt(world, world + facing))
                prop.Parent = model
            end
            -- Sparse on purpose: a few pieces read as a room; a wall of them is a mobile frame drop
            t += size.X + rng:NextNumber(50, 100)
        end
    end
end

-- Pools of light on a grid, skipping anywhere a wall stands. Never solid to a
-- raycast, so they cannot block a shot or a witness sightline.
local function lamps(model: Model, def, h: number)
    for x = LAMP_SPACING / 2, W, LAMP_SPACING do
        for z = LAMP_SPACING / 2, D, LAMP_SPACING do
            if insideAny(def.walls, x, z, 6) then
                continue
            end
            local pos = Vector3.new(x - W / 2, h - 3, z - D / 2)
            if def.lampPosts then
                local post = part(
                    ("LampPost_%d_%d"):format(x, z),
                    model,
                    Vector3.new(0.6, h - 3, 0.6),
                    Vector3.new(pos.X, (h - 3) / 2, pos.Z),
                    Color3.fromHex("2b2f33"),
                    Enum.Material.Metal
                )
                post.CanQuery = false
            end
            local lamp = part(
                ("Lamp_%d_%d"):format(x, z),
                model,
                Vector3.new(1.4, 0.7, 1.4),
                pos,
                def.lamp,
                Enum.Material.Neon
            )
            lamp.CanCollide = false
            lamp.CanQuery = false
            lamp.CanTouch = false
            lamp.CastShadow = false
            lamp:AddTag("MapLight")
            local light = Instance.new("PointLight")
            light.Color = def.lamp
            light.Range = 52
            light.Brightness = 1.3
            light.Shadows = true
            light.Parent = lamp
        end
    end
end

return function(opts: { force: boolean? }?)
    local ServerStorage = game:GetService("ServerStorage")
    local force = opts and opts.force

    local folder = ServerStorage:FindFirstChild("Maps")
    if folder and not force then
        return folder
    end
    if folder then
        folder:Destroy()
    end
    folder = Instance.new("Folder")
    folder.Name = "Maps"

    for mapName, def in MAPS do
        local model = Instance.new("Model")
        model.Name = mapName
        model.Parent = folder
        local h = def.height

        local floor = part(
            "Floor_Base",
            model,
            Vector3.new(W, 2, D),
            Vector3.new(0, -1, 0),
            def.floor,
            def.floorMaterial
        )
        model.PrimaryPart = floor

        for i, r in def.walls do
            -- The first four walls are always the outer shell
            local outer = i <= 4
            part(
                ("Wall_%02d"):format(i),
                model,
                Vector3.new(r[3], h, r[4]),
                rectCentre(r, h),
                outer and def.outer or def.wall,
                outer and def.outerMaterial or def.wallMaterial
            )
        end
        lamps(model, def, h)
        dress(model, def, #mapName * 7919)

        for i, r in def.doors do
            local door = part(
                ("Door_%02d"):format(i),
                model,
                Vector3.new(r[3], h, r[4]),
                rectCentre(r, h),
                Color3.fromHex("5b3a24"),
                Enum.Material.Wood
            )
            door.CanCollide = false
            door.Transparency = 1
            door:AddTag("LockdownDoor")
        end

        for i, s in def.spawns do
            local p = part(
                ("Spawn_%02d"):format(i),
                model,
                Vector3.new(8, 0.4, 8),
                Vector3.new(s[1] - W / 2, 0.2, s[2] - D / 2),
                Color3.fromHex("37bcf0")
            )
            p.CanCollide = false
            p.Transparency = 0.55
            p:AddTag("SpawnPoint")
        end

        for i, c in def.coins do
            local p = part(
                ("Coin_%02d"):format(i),
                model,
                Vector3.new(2, 2, 0.4),
                Vector3.new(c[1] - W / 2, 3, c[2] - D / 2),
                Color3.fromHex("f2a63b")
            )
            p.CanCollide = false
            p.CanQuery = false
            p.Material = Enum.Material.Neon
            p:SetAttribute("NodeId", i)
            p:AddTag("CoinNode")
        end
    end

    if not ServerStorage:FindFirstChild("BodyTemplate") then
        local body = Instance.new("Model")
        body.Name = "BodyTemplate"
        local torso = part(
            "Torso",
            body,
            Vector3.new(4, 1, 2),
            Vector3.new(0, 0.5, 0),
            Color3.fromHex("8c3330")
        )
        torso.CanCollide = false
        body.PrimaryPart = torso
        body.Parent = ServerStorage
    end

    folder.Parent = ServerStorage
    return folder
end
