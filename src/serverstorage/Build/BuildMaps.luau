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
        props = { "Bookshelf", "Armchair", "GrandfatherClock", "Fireplace" },
        interior = { "DiningTable", "Sofa", "GrandPiano", "Armchair" },
        trim = "2a1d15",
        windows = true,
        paintings = true,
        rugs = { "5a1f24", "1f3a2e", "3a2a4a", "4a3520" },
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
        props = { "CrateStack", "Barrel", "LobsterTraps", "RopeCoil" },
        interior = { "CrateStack", "Barrel", "RopeCoil", "LobsterTraps", "Anchor", "Bollard" },
        pier = true,
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
        props = { "FilingCabinet", "Bookshelf", "CardCatalog" },
        interior = { "WritingDesk", "CardCatalog", "Globe", "FilingCabinet" },
        trim = "3a2a1c",
        windows = true,
        shelves = true,
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
local LAMP_SPACING = 120
local WINDOW_SPACING = 110
local INTERIOR_MAX = 22 -- furniture pieces placed inside the rooms per map
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

-- Decoration never collides and is invisible to raycasts, so it can never
-- block a route, a shot or a witness sightline. Hundreds of small pieces
-- cast no shadows, which keeps the shelved archive cheap on mobile.
local function deco(name, parent, size, pos, colour, material: Enum.Material?)
    local p = part(name, parent, size, pos, colour, material)
    p.CanCollide = false
    p.CanQuery = false
    p.CanTouch = false
    p.CastShadow = false
    return p
end

-- The two long faces of a wall rect: the plan axis they run along, where the
-- face sits, which way it points, and the span it covers
local function longFaces(r)
    if r[4] >= r[3] then
        return {
            { along = "z", at = r[1], normal = -1, from = r[2], to = r[2] + r[4] },
            { along = "z", at = r[1] + r[3], normal = 1, from = r[2], to = r[2] + r[4] },
        }
    end
    return {
        { along = "x", at = r[2], normal = -1, from = r[1], to = r[1] + r[3] },
        { along = "x", at = r[2] + r[4], normal = 1, from = r[1], to = r[1] + r[3] },
    }
end

-- A world position `out` studs off a face, `t` studs along it, at height y
local function onFace(face, t: number, out: number, y: number): Vector3
    if face.along == "z" then
        return Vector3.new(face.at + face.normal * out - W / 2, y, t - D / 2)
    end
    return Vector3.new(t - W / 2, y, face.at + face.normal * out - D / 2)
end

-- A box `length` along a face and `depth` out from it
local function faceSize(face, length: number, height: number, depth: number): Vector3
    return if face.along == "z"
        then Vector3.new(depth, height, length)
        else Vector3.new(length, height, depth)
end

-- The face of an outer wall that looks into the map
local function isInnerFace(face): boolean
    local edge = if face.along == "x" then D else W
    return face.at ~= 0 and face.at ~= edge
end

local FACE_NORMAL = {
    x = { [1] = Enum.NormalId.Back, [-1] = Enum.NormalId.Front },
    z = { [1] = Enum.NormalId.Right, [-1] = Enum.NormalId.Left },
}

local function overlaps(a, b): boolean
    return a[1] < b[1] + b[3] and a[1] + a[3] > b[1] and a[2] < b[2] + b[4] and a[2] + a[4] > b[2]
end

-- Does a plan rect touch a door or any wall other than `skip`?
local function touchesStructure(def, rect, skip: number?, outerToo: boolean?): boolean
    for i, r in def.walls do
        if i ~= skip and (outerToo or i > 4) and overlaps(rect, r) then
            return true
        end
    end
    for _, r in def.doors do
        if overlaps(rect, r) then
            return true
        end
    end
    return false
end

-- Skirting and a cornice on every wall, so walls read as built, not boxes
local function trimWalls(model: Model, def, h: number)
    if not def.trim then
        return
    end
    local wood = Color3.fromHex(def.trim)
    for i, r in def.walls do
        local c = rectCentre(r, h)
        deco(
            ("Skirting_%02d"):format(i),
            model,
            Vector3.new(r[3] + 0.6, 1.2, r[4] + 0.6),
            Vector3.new(c.X, 0.6, c.Z),
            wood,
            Enum.Material.Wood
        )
        deco(
            ("Cornice_%02d"):format(i),
            model,
            Vector3.new(r[3] + 1, 0.8, r[4] + 1),
            Vector3.new(c.X, h + 0.4, c.Z),
            wood,
            Enum.Material.Wood
        )
    end
end

-- Tall windows along the outer walls, each throwing a wash of moonlight
local function windows(model: Model, def, h: number)
    if not def.windows then
        return
    end
    local wood = Color3.fromHex(def.trim or "3a2a1c")
    local y = h * 0.55
    for i = 1, 4 do
        for _, face in longFaces(def.walls[i]) do
            if not isInnerFace(face) then
                continue
            end
            for t = face.from + 60, face.to - 60, WINDOW_SPACING do
                local probe = if face.along == "x"
                    then { t - 8, face.at - 12, 16, 24 }
                    else { face.at - 12, t - 8, 24, 16 }
                if touchesStructure(def, probe, i) then
                    continue -- an inner wall or a door meets the wall here
                end
                local glass = deco(
                    "Window",
                    model,
                    faceSize(face, 8, 9, 0.2),
                    onFace(face, t, 0.15, y),
                    Color3.fromHex("6f8fb3"),
                    Enum.Material.Glass
                )
                glass.Transparency = 0.25
                local light = Instance.new("SurfaceLight")
                light.Face = FACE_NORMAL[face.along][face.normal]
                light.Color = Color3.fromHex("a9c7ff")
                light.Brightness = 1.4
                light.Range = 28
                light.Angle = 70
                light.Parent = glass
                for _, bar in
                    {
                        { 9, 0.6, 0, 4.7 },
                        { 9, 0.6, 0, -4.7 },
                        { 0.6, 10, 4.5, 0 },
                        { 0.6, 10, -4.5, 0 },
                        { 0.3, 9, 0, 0 },
                        { 8, 0.3, 0, 0 },
                    }
                do
                    deco(
                        "WindowFrame",
                        model,
                        faceSize(face, bar[1], bar[2], 0.5),
                        onFace(face, t + bar[3], 0.3, y + bar[4]),
                        wood,
                        Enum.Material.Wood
                    )
                end
            end
        end
    end
end

local CANVAS = { "7a4a2e", "3e5a4a", "5a3a4a", "8a7a5a", "2e3e5a", "6a2e2e" }

-- Framed paintings on the long faces of inner walls
local function paintings(model: Model, def, h: number, rng: Random)
    if not def.paintings then
        return
    end
    local gilt = Color3.fromHex("8a6a2e")
    for i, r in def.walls do
        if i <= 4 then
            continue
        end
        for _, face in longFaces(r) do
            if face.to - face.from < 50 then
                continue
            end
            for t = face.from + 25, face.to - 25, 55 do
                if rng:NextNumber() < 0.35 then
                    continue
                end
                local probe = if face.along == "x"
                    then { t - 5, face.at - 6, 10, 12 }
                    else { face.at - 6, t - 5, 12, 10 }
                if touchesStructure(def, probe, i) then
                    continue
                end
                deco(
                    "PaintingFrame",
                    model,
                    faceSize(face, 7, 5.5, 0.3),
                    onFace(face, t, 0.15, h * 0.5),
                    gilt,
                    Enum.Material.Wood
                )
                deco(
                    "Painting",
                    model,
                    faceSize(face, 6, 4.5, 0.12),
                    onFace(face, t, 0.34, h * 0.5),
                    Color3.fromHex(CANVAS[rng:NextInteger(1, #CANVAS)])
                )
            end
        end
    end
end

local BOOKS = { "6b2e2a", "2e4a6b", "4a6b2e", "8a6a2a", "5a3a6a", "2a5a5a", "7a5a3a", "3a3a3a" }

-- The archive's inner walls are shelving: planks and rows of book spines
local function shelves(model: Model, def, rng: Random)
    if not def.shelves then
        return
    end
    local wood = Color3.fromHex(def.trim or "3a2a1c")
    for i, r in def.walls do
        if i <= 4 then
            continue
        end
        for _, face in longFaces(r) do
            local mid = (face.from + face.to) / 2
            for row = 1, 3 do
                local y = 1.5 + (row - 1) * 5.5
                deco(
                    "Shelf",
                    model,
                    faceSize(face, face.to - face.from - 1, 0.3, 1.4),
                    onFace(face, mid, 0.7, y),
                    wood,
                    Enum.Material.WoodPlanks
                )
                local t = face.from + 1
                while t < face.to - 3 do
                    local length = math.min(rng:NextNumber(10, 22), face.to - 1 - t)
                    local height = rng:NextNumber(2.4, 3.8)
                    deco(
                        "Books",
                        model,
                        faceSize(face, length - 0.4, height, 1.1),
                        onFace(face, t + length / 2, 0.6, y + 0.15 + height / 2),
                        Color3.fromHex(BOOKS[rng:NextInteger(1, #BOOKS)]),
                        Enum.Material.Fabric
                    )
                    t += length
                end
            end
        end
    end
end

-- Rugs with a darker border, laid anywhere clear of walls
local function rugs(model: Model, def, rng: Random)
    if not def.rugs then
        return
    end
    for _ = 1, 14 do
        local w, d = rng:NextNumber(14, 22), rng:NextNumber(9, 13)
        local x, z = rng:NextNumber(40, W - 40), rng:NextNumber(40, D - 40)
        if touchesStructure(def, { x - w / 2 - 3, z - d / 2 - 3, w + 6, d + 6 }, nil, true) then
            continue
        end
        local colour = Color3.fromHex(def.rugs[rng:NextInteger(1, #def.rugs)])
        local h, s, v = colour:ToHSV()
        deco(
            "RugBorder",
            model,
            Vector3.new(w + 1.2, 0.1, d + 1.2),
            Vector3.new(x - W / 2, 0.05, z - D / 2),
            Color3.fromHSV(h, s, v * 0.55),
            Enum.Material.Fabric
        )
        deco(
            "Rug",
            model,
            Vector3.new(w, 0.14, d),
            Vector3.new(x - W / 2, 0.07, z - D / 2),
            colour,
            Enum.Material.Fabric
        )
    end
end

-- Rusted Pier: open water around the deck, pilings and a railing along the
-- edge. The outer walls stay as invisible barriers.
local function pierDressing(model: Model, def)
    if not def.pier then
        return
    end
    local water = deco(
        "Water",
        model,
        Vector3.new(W + 800, 1, D + 800),
        Vector3.new(0, -5, 0),
        Color3.fromHex("163246"),
        Enum.Material.Glass
    )
    water.Transparency = 0.15
    water.Reflectance = 0.2
    local wood = Color3.fromHex("4a3a2a")
    for i = 1, 4 do
        for _, face in longFaces(def.walls[i]) do
            if not isInnerFace(face) then
                continue
            end
            local t = face.from + 2
            while t <= face.to - 2 do
                deco(
                    "Piling",
                    model,
                    Vector3.new(0.7, 12, 0.7),
                    onFace(face, t, 0.5, -2),
                    wood,
                    Enum.Material.Wood
                )
                t += 12
            end
            local mid = (face.from + face.to) / 2
            local length = face.to - face.from - 4
            deco(
                "Rail",
                model,
                faceSize(face, length, 0.35, 0.35),
                onFace(face, mid, 0.5, 3.8),
                wood,
                Enum.Material.Wood
            )
            deco(
                "Rail",
                model,
                faceSize(face, length, 0.3, 0.3),
                onFace(face, mid, 0.5, 2),
                wood,
                Enum.Material.Wood
            )
        end
    end
end

local function placeProp(model: Model, template: Model, cf: CFrame)
    local prop = template:Clone()
    for _, d in prop:GetDescendants() do
        if d:IsA("LuaSourceContainer") then
            d:Destroy() -- set dressing never runs code
        elseif d:IsA("BasePart") then
            d.Anchored = true
        end
    end
    prop:PivotTo(cf)
    prop.Parent = model
end

-- Furniture inside the rooms: a jittered grid of spots, each clear of walls,
-- doors, spawns, coins and other furniture. A dining table brings its chairs.
local function furnish(model: Model, def, seed: number)
    local folder = game:GetService("ServerStorage"):FindFirstChild("Props")
    if not folder or not def.interior then
        return
    end
    local rng = Random.new(seed)
    local placed: { { x: number, z: number, r: number } } = {}
    local count = 0
    for gx = 50, W - 50, 70 do
        for gz = 50, D - 50, 70 do
            if count >= INTERIOR_MAX or rng:NextNumber() > 0.55 then
                continue
            end
            local name = def.interior[rng:NextInteger(1, #def.interior)]
            local template = folder:FindFirstChild(name)
            if not (template and template:IsA("Model")) then
                continue
            end
            local size = template:GetExtentsSize()
            local turned = rng:NextInteger(0, 1) == 1
            local chairs = name == "DiningTable" and 3 or 0 -- room for chairs around it
            local sx = (if turned then size.Z else size.X) + chairs * 2
            local sz = (if turned then size.X else size.Z) + chairs * 2
            local x, z = gx + rng:NextNumber(-15, 15), gz + rng:NextNumber(-15, 15)
            local x0, z0, x1, z1 = x - sx / 2, z - sz / 2, x + sx / 2, z + sz / 2
            if
                touchesStructure(def, { x0 - 8, z0 - 8, sx + 16, sz + 16 }, nil, true)
                or blocked(def, x0, z0, x1, z1)
            then
                continue
            end
            local radius = math.max(sx, sz) / 2
            local crowded = false
            for _, other in placed do
                if math.sqrt((other.x - x) ^ 2 + (other.z - z) ^ 2) < radius + other.r + 10 then
                    crowded = true
                    break
                end
            end
            if crowded then
                continue
            end
            table.insert(placed, { x = x, z = z, r = radius })
            count += 1

            local yaw = (if turned then 90 else 0) + rng:NextInteger(0, 1) * 180
            local cf = CFrame.new(x - W / 2, size.Y / 2, z - D / 2)
                * CFrame.Angles(0, math.rad(yaw), 0)
            placeProp(model, template, cf)

            local chair = folder:FindFirstChild("DiningChair")
            if name == "DiningTable" and chair and chair:IsA("Model") then
                local chairSize = chair:GetExtentsSize()
                for _, spot in { { -0.25, 1 }, { 0.25, 1 }, { -0.25, -1 }, { 0.25, -1 } } do
                    local offset = Vector3.new(
                        size.X * spot[1],
                        0,
                        spot[2] * (size.Z / 2 + chairSize.Z / 2 + 0.6)
                    )
                    local at = cf:PointToWorldSpace(offset)
                    at = Vector3.new(at.X, chairSize.Y / 2, at.Z)
                    local centre = Vector3.new(cf.Position.X, at.Y, cf.Position.Z)
                    placeProp(model, chair, CFrame.lookAt(at, centre))
                end
            end
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
            light.Range = 60
            light.Brightness = 1.6
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
            local wall = part(
                ("Wall_%02d"):format(i),
                model,
                Vector3.new(r[3], h, r[4]),
                rectCentre(r, h),
                outer and def.outer or def.wall,
                outer and def.outerMaterial or def.wallMaterial
            )
            if outer and def.pier then
                wall.Transparency = 1 -- the pier's edge is a railing over open water
                wall.CastShadow = false
            end
        end
        local rng = Random.new(#mapName * 104729)
        trimWalls(model, def, h)
        windows(model, def, h)
        paintings(model, def, h, rng)
        shelves(model, def, rng)
        rugs(model, def, rng)
        pierDressing(model, def)
        lamps(model, def, h)
        dress(model, def, #mapName * 7919)
        furnish(model, def, #mapName * 15485863)

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
