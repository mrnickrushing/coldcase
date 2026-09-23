--[[
  COLD CASE · map builder
  Bootstrap runs this when ServerStorage.Maps is missing, so a fresh
  `rojo build` is playable. From the command bar:
    require(game.ServerStorage.Build.BuildMaps)({ force = true })
  Builds every building in Shared/MapPlan as a Model in ServerStorage.Maps:
  floors and roofs, walls with doorways, railings round stairwells and
  balconies, staircases with steps and banisters, moonlit windows, lamps tagged
  MapLight (Lights Out turns them off), LockdownDoors, SpawnPoints and
  CoinNodes, then furniture from ServerStorage.Props when it exists.
]]
local ServerStorage = game:GetService("ServerStorage")
local MapPlan = require(game.ReplicatedStorage.Shared.MapPlan)
local Shuffle = require(game.ReplicatedStorage.Shared.Shuffle)

local CELL, H = MapPlan.CELL, MapPlan.FLOOR_HEIGHT
local WALL = 1.4 -- interior wall thickness
local SHELL = 2 -- exterior wall thickness
local SLAB = 1
local DOOR_W, DOOR_H = 9, 10
local RAIL_H = 3.6 -- waist high: blocks a stumble, not a jump
local RESERVED_CLEAR = 4.5 -- studs kept free round the centre of a spawn or coin cell (the pad is 8 wide)
local STAIR_W = CELL - 4
local M = Enum.Material

-- Real materials read far better than flat plastic. Pick a floor material from
-- its colour: warm browns become wood planks, low-saturation greys become
-- concrete, and light stone/tile keeps the style's (polished) material.
local function floorMaterialFor(hex: string, fallback: Enum.Material): Enum.Material
    local h, sat, v = Color3.fromHex(hex):ToHSV()
    local deg = h * 360
    if deg >= 18 and deg <= 46 and sat > 0.14 and v < 0.74 then
        return M.WoodPlanks
    end
    if sat < 0.12 and v < 0.63 then
        return M.Concrete
    end
    return fallback
end
local SIDES = { "N", "E", "S", "W" }

-- Per map: shell and wall finishes, then a style per region kind. A style's
-- `props` stand against walls (one per cell at most, `density` of the time),
-- `centre` stands in the room's most open cell, `chairs` seats a table, `rug`
-- lies under the centrepiece, and `againstRail` lets props line railings.
local THEMES = {
    BlackwoodManor = {
        wall = "d8c9a8",
        wallMaterial = M.SmoothPlastic,
        shell = "b5714c",
        shellMaterial = M.Brick,
        roof = "5a4740",
        roofMaterial = M.Slate,
        trim = "f0eadc",
        dado = "8a5a3a",
        liner = true,
        ceiling = "f2efe6",
        ceilingMaterial = M.Plaster,
        rail = "8a5a3a",
        railMaterial = M.Wood,
        stair = "a9855c",
        stairMaterial = M.SmoothPlastic,
        lamp = "ffe0a8",
        windows = true,
        -- Framed oils in dark gilt: the family's collection
        pictures = {
            frame = "8a6a2e",
            frameMaterial = M.Wood,
            canvases = { "7a4a2e", "3e5a4a", "5a3a4a", "8a7a5a", "2e3e5a", "6a2e2e" },
            width = 7,
            height = 5.5,
            chance = 0.3,
        },
        -- A dark wooden waste basket with a brass rim
        bin = {
            colour = "4a3a2c",
            material = M.Wood,
            rim = "b08a3a",
            rimMaterial = M.Metal,
            height = 3,
            diameter = 2.2,
        },
        styles = {
            hall = {
                wall = "d8c9a8",
                floor = "8a5a3a",
                floorMaterial = M.SmoothPlastic,
                props = { "GrandfatherClock", "Plant" },
                density = 0.12,
            },
            tunnel = {
                wall = "a89f92",
                floor = "9a958c",
                floorMaterial = M.SmoothPlastic,
                props = { "Barrel", "CrateStack" },
                density = 0.2,
            },
            cellar = {
                wall = "b09a7a",
                floor = "8a8070",
                floorMaterial = M.SmoothPlastic,
                clutter = 0.45,
                props = { "Barrel", "Barrel", "CrateStack" },
                density = 0.6,
            },
            boiler = {
                wall = "9aa3ab",
                floor = "8c8c8c",
                floorMaterial = M.SmoothPlastic,
                props = { "Barrel", "CrateStack" },
                density = 0.4,
            },
            storage = {
                wall = "c0a878",
                floor = "8a7a62",
                floorMaterial = M.SmoothPlastic,
                clutter = 0.45,
                props = { "CrateStack", "Barrel" },
                density = 0.5,
            },
            library = {
                wall = "8a4f36",
                floor = "9a6a44",
                floorMaterial = M.SmoothPlastic,
                props = { "Bookshelf", "Plant" },
                density = 0.8,
                centre = "WritingDesk",
                rug = "b03a3a",
            },
            grandhall = {
                wall = "efe2c4",
                floor = "d8cfc0",
                floorMaterial = M.SmoothPlastic,
                props = { "GrandfatherClock", "Armchair", "Plant" },
                density = 0.15,
                centre = "Globe",
                rug = "b03a3a",
            },
            dining = {
                wall = "a85a55",
                floor = "9a6a44",
                floorMaterial = M.SmoothPlastic,
                props = { "Fireplace", "Bookshelf", "GrandfatherClock" },
                density = 0.35,
                centre = "DiningTable",
                chairs = true,
                rug = "2f7a5a",
            },
            parlour = {
                wall = "6f9a84",
                floor = "9a6a44",
                floorMaterial = M.SmoothPlastic,
                props = {
                    "Sofa",
                    "Armchair",
                    "Fireplace",
                    "SofaRed",
                    "Television",
                    "Plant",
                    "Arcade",
                },
                density = 0.45,
                centre = "GrandPiano",
                rug = "7a4aa0",
            },
            kitchen = {
                wall = "cfd8d8",
                floor = "d2d2ca",
                floorMaterial = M.SmoothPlastic,
                props = { "Barrel", "CrateStack", "FilingCabinet", "KitchenCounter", "Fridge" },
                density = 0.4,
                centre = "DiningTable",
                chairs = true, -- a kitchen table reads bare without seats
            },
            study = {
                wall = "5f83a0",
                floor = "9a6a44",
                floorMaterial = M.SmoothPlastic,
                props = { "Bookshelf", "FilingCabinet", "Globe", "Plant" },
                density = 0.55,
                centre = "WritingDesk",
                rug = "c8901f",
            },
            bedroom = {
                wall = "c8a0b8",
                floor = "9a6a44",
                floorMaterial = M.SmoothPlastic,
                props = { "Armchair", "Bookshelf", "Fireplace", "GrandfatherClock", "Bed", "Plant" },
                density = 0.4,
                centre = "Bed",
                rug = "3f6fb0",
            },
            bathroom = {
                wall = "bfe0e8",
                floor = "eef4f6",
                floorMaterial = M.SmoothPlastic,
                props = {},
                density = 0,
            },
        },
    },

    RustedPier = {
        wall = "9fb3bd",
        wallMaterial = M.SmoothPlastic,
        shell = "5f8fa8",
        shellMaterial = M.Metal,
        roof = "3f5f70",
        roofMaterial = M.Metal,
        trim = "e8f0f4",
        liner = true,
        rail = "b0703a",
        railMaterial = M.Wood,
        stair = "b08b5e",
        stairMaterial = M.SmoothPlastic,
        lamp = "ffd27a",
        windows = true,
        -- Pinned notices and tide tables in cheap dark frames
        pictures = {
            frame = "3a3f44",
            frameMaterial = M.Metal,
            canvases = { "e8e2cc", "d9cfb0", "c9b89a", "b7b3a8", "8c6b4a", "a9b7bd" },
            width = 5,
            height = 4,
            chance = 0.4,
        },
        -- A galvanised bin with a lid
        bin = {
            colour = "7d8388",
            material = M.Metal,
            rim = "5a5f63",
            rimMaterial = M.Metal,
            lid = true,
            height = 3.4,
            diameter = 2.6,
        },
        water = true,
        styles = {
            boardwalk = {
                floor = "a07a4a",
                floorMaterial = M.SmoothPlastic,
                props = { "RopeCoil", "LobsterTraps", "Bollard" },
                density = 0.35,
                againstRail = true,
            },
            boathouse = {
                wall = "7fa8c0",
                floor = "a9855c",
                floorMaterial = M.SmoothPlastic,
                clutter = 0.45,
                props = { "CrateStack", "Barrel", "RopeCoil", "Anchor" },
                density = 0.5,
                centre = "LobsterTraps",
            },
            deck = {
                floor = "b0854f",
                floorMaterial = M.SmoothPlastic,
                props = { "Bollard", "RopeCoil", "LobsterTraps", "Barrel", "Anchor" },
                density = 0.35,
                againstRail = true,
            },
            warehouse = {
                wall = "9fb3bd",
                floor = "6f7278",
                floorMaterial = M.SmoothPlastic,
                clutter = 0.55,
                props = { "CrateStack", "Barrel" },
                density = 0.6,
                centre = "CrateStack",
            },
            office = {
                wall = "e0d8a8",
                floor = "a9855c",
                floorMaterial = M.SmoothPlastic,
                props = {
                    "FilingCabinet",
                    "Bookshelf",
                    "VendingMachine",
                    "Fridge",
                    "Arcade",
                    "Plant",
                },
                density = 0.55,
                centre = "WritingDesk",
            },
            coldstore = {
                wall = "cfe4ec",
                floor = "c0cdd4",
                floorMaterial = M.SmoothPlastic,
                props = { "CrateStack", "Barrel", "Fridge" },
                density = 0.55,
            },
            catwalk = {
                wall = "9fb3bd",
                floor = "8fa0aa",
                floorMaterial = M.SmoothPlastic,
                props = {},
                density = 0,
            },
            roof = {
                floor = "93a3ad",
                floorMaterial = M.SmoothPlastic,
                props = { "Barrel", "CrateStack" },
                density = 0.25,
                againstRail = true,
            },
        },
    },

    CityArchive = {
        wall = "e0d8c0",
        wallMaterial = M.SmoothPlastic,
        shell = "cfc7b4",
        shellMaterial = M.Concrete,
        roof = "6a6f74",
        roofMaterial = M.Concrete,
        trim = "f4f0e4",
        dado = "8a6a44",
        liner = true,
        ceiling = "f4f2ea",
        ceilingMaterial = M.Plaster,
        rail = "9aa4ac",
        railMaterial = M.Metal,
        stair = "d8d2c4",
        stairMaterial = M.SmoothPlastic,
        lamp = "ffeccf",
        -- Framed maps and documents in plain dark wood
        pictures = {
            frame = "5a3f2a",
            frameMaterial = M.Wood,
            canvases = { "e9dfc4", "dccfae", "cbbf9e", "b9a57e", "d8d0bc", "a8977a" },
            width = 6.5,
            height = 5,
            chance = 0.3,
        },
        -- A matte office bin
        bin = {
            colour = "3c4148",
            material = M.SmoothPlastic,
            rim = "6a7078",
            rimMaterial = M.SmoothPlastic,
            height = 3,
            diameter = 2.2,
        },
        windows = true,
        styles = {
            vault = {
                wall = "b9c2c8",
                floor = "a8b0b6",
                floorMaterial = M.SmoothPlastic,
                clutter = 0.3,
                props = { "FilingCabinet", "CardCatalog" },
                density = 0.65,
            },
            corridor = {
                wall = "e0d8c0",
                floor = "b8b1a2",
                floorMaterial = M.SmoothPlastic,
                props = { "FilingCabinet", "Plant" },
                density = 0.12,
            },
            storage = {
                wall = "c8bfa8",
                floor = "b0a894",
                floorMaterial = M.SmoothPlastic,
                props = { "CrateStack", "FilingCabinet" },
                density = 0.5,
            },
            office = {
                wall = "cfe0d0",
                floor = "a9855c",
                floorMaterial = M.SmoothPlastic,
                props = { "FilingCabinet", "Bookshelf", "Globe", "Plant" },
                density = 0.55,
                centre = "WritingDesk",
                rug = "2f5fa0",
            },
            hall = {
                wall = "e6dcc4",
                floor = "c2bcae",
                floorMaterial = M.SmoothPlastic,
                props = { "CardCatalog", "Plant", "VendingMachine" },
                density = 0.1,
            },
            reading = {
                wall = "9a6a44",
                floor = "a9855c",
                floorMaterial = M.SmoothPlastic,
                props = { "Bookshelf", "Plant" },
                density = 0.6,
                centre = "WritingDesk",
                rug = "2f5fa0",
            },
            records = {
                wall = "d8d0b8",
                floor = "b8b1a2",
                floorMaterial = M.SmoothPlastic,
                clutter = 0.3,
                props = { "FilingCabinet", "CardCatalog", "Bookshelf" },
                density = 0.65,
            },
            exhibits = {
                wall = "cfd8e4",
                floor = "e4e0d6",
                floorMaterial = M.SmoothPlastic,
                props = { "Globe", "GrandfatherClock" },
                density = 0.4,
                centre = "Globe",
            },
            lobby = {
                wall = "efe6d0",
                floor = "e8e2d6",
                floorMaterial = M.SmoothPlastic,
                props = { "Armchair", "GrandfatherClock", "SofaRed", "Plant", "VendingMachine" },
                centre = "SofaRed",
                density = 0.25,
                rug = "b03a3a",
            },
            maps = {
                wall = "c8d8c0",
                floor = "a9855c",
                floorMaterial = M.SmoothPlastic,
                props = { "CardCatalog", "Globe" },
                density = 0.55,
                centre = "DiningTable",
            },
            stacks = {
                wall = "a97a4a",
                floor = "a9855c",
                floorMaterial = M.SmoothPlastic,
                clutter = 0.35,
                props = { "Bookshelf" },
                density = 0.5,
            },
            lab = {
                wall = "d8e8e0",
                floor = "eef2f0",
                floorMaterial = M.SmoothPlastic,
                props = { "FilingCabinet", "WritingDesk", "KitchenCounter" },
                density = 0.45,
                centre = "DiningTable",
            },
            carrels = {
                wall = "c0b088",
                floor = "a9855c",
                floorMaterial = M.SmoothPlastic,
                props = { "WritingDesk" },
                density = 0.7,
            },
        },
    },
}

local function part(
    name: string,
    parent: Instance,
    size: Vector3,
    cf: CFrame,
    colour: Color3,
    material: Enum.Material?
): Part
    local p = Instance.new("Part")
    p.Name = name
    p.Anchored = true
    p.Size = size
    p.CFrame = cf
    p.Color = colour
    p.Material = material or M.SmoothPlastic
    p.TopSurface = Enum.SurfaceType.Smooth
    p.BottomSurface = Enum.SurfaceType.Smooth
    p.Parent = parent
    return p
end

-- Decoration never collides, casts no shadow and is invisible to raycasts, so
-- it can never block a route, a shot or a witness sightline
local function deco(
    name: string,
    parent: Instance,
    size: Vector3,
    cf: CFrame,
    colour: Color3,
    material: Enum.Material?
): Part
    local p = part(name, parent, size, cf, colour, material)
    p.CanCollide = false
    p.CanQuery = false
    p.CanTouch = false
    p.CastShadow = false
    return p
end

-- World coordinate of grid line `line` across `cells` cells centred on 0
local function lineAt(line: number, cells: number): number
    return (line - cells / 2) * CELL
end

-- A box `length` along `along`, `thickness` across it
local function boxSize(along: Vector3, length: number, height: number, thickness: number): Vector3
    return if along.X ~= 0
        then Vector3.new(length, height, thickness)
        else Vector3.new(thickness, height, length)
end

local function faceToward(v: Vector3): Enum.NormalId
    if v.X > 0.5 then
        return Enum.NormalId.Right
    elseif v.X < -0.5 then
        return Enum.NormalId.Left
    elseif v.Z > 0.5 then
        return Enum.NormalId.Back
    end
    return Enum.NormalId.Front
end

-- Greedy rectangles over the cells `keyOf` gives a key, one per run of equal keys
local function rectangles(gw: number, gd: number, keyOf: (number, number) -> string?)
    local used = {}
    local out = {}
    for z = 1, gd do
        for x = 1, gw do
            local key = keyOf(x, z)
            if key == nil or used[z * 1000 + x] then
                continue
            end
            local x1 = x
            while x1 < gw and not used[z * 1000 + x1 + 1] and keyOf(x1 + 1, z) == key do
                x1 += 1
            end
            local z1 = z
            while z1 < gd do
                local fits = true
                for xx = x, x1 do
                    if used[(z1 + 1) * 1000 + xx] or keyOf(xx, z1 + 1) ~= key then
                        fits = false
                        break
                    end
                end
                if not fits then
                    break
                end
                z1 += 1
            end
            for zz = z, z1 do
                for xx = x, x1 do
                    used[zz * 1000 + xx] = true
                end
            end
            table.insert(out, { x0 = x, z0 = z, x1 = x1, z1 = z1, key = key })
        end
    end
    return out
end

local function rectPart(
    name: string,
    model: Model,
    gw: number,
    gd: number,
    r,
    y: number,
    colour,
    material,
    thickness: number?
)
    local size = Vector3.new((r.x1 - r.x0 + 1) * CELL, thickness or SLAB, (r.z1 - r.z0 + 1) * CELL)
    local centre = Vector3.new(
        (lineAt(r.x0 - 1, gw) + lineAt(r.x1, gw)) / 2,
        y,
        (lineAt(r.z0 - 1, gd) + lineAt(r.z1, gd)) / 2
    )
    return part(name, model, size, CFrame.new(centre), colour, material)
end

---------------------------------------------------------------- Floors and roofs
local function slabs(model: Model, plan, analysis, theme): BasePart?
    local gw, gd, floors = MapPlan.Size(plan)
    local first: BasePart? = nil
    for f = 1, floors do
        local base = (f - 1) * H
        for _, r in
            rectangles(gw, gd, function(x, z)
                local ch = MapPlan.Cell(plan, f, x, z)
                return if MapPlan.IsWalkable(ch) then plan.regions[ch].style else nil
            end)
        do
            local style = theme.styles[r.key] or theme.styles.hall
            local p = rectPart(
                "Floor",
                model,
                gw,
                gd,
                r,
                base - SLAB / 2,
                Color3.fromHex(style.floor),
                floorMaterialFor(style.floor, style.floorMaterial)
            )
            first = first or p
        end
        for _, r in
            rectangles(gw, gd, function(x, z)
                return if analysis.roof[MapPlan.Key(f, x, z)] then "roof" else nil
            end)
        do
            rectPart(
                "Roof",
                model,
                gw,
                gd,
                r,
                base + H - SLAB / 2,
                Color3.fromHex(theme.roof),
                theme.roofMaterial
            )
        end
        if theme.ceiling then
            for _, r in
                rectangles(gw, gd, function(x, z)
                    -- A stairwell or a double-height hall is still a room
                    -- from below: without a panel over its ^ cells the room
                    -- looks up at the raw underside of the slab or roof above
                    local ch = MapPlan.Cell(plan, f, x, z)
                    local space = if ch == "^" then MapPlan.OpensInto(plan, f, x, z) else ch
                    if
                        not space
                        or not MapPlan.IsWalkable(space)
                        or plan.regions[space].outdoor
                    then
                        return nil
                    end
                    local covered = analysis.roof[MapPlan.Key(f, x, z)]
                        or MapPlan.IsWalkable(MapPlan.Cell(plan, f + 1, x, z))
                    return if covered then "ceiling" else nil
                end)
            do
                local ceiling = rectPart(
                    "Ceiling",
                    model,
                    gw,
                    gd,
                    r,
                    base + H - SLAB - 0.15,
                    Color3.fromHex(theme.ceiling),
                    theme.ceilingMaterial,
                    0.3
                )
                ceiling.CanCollide = false
                ceiling.CanQuery = false
                ceiling.CastShadow = false
            end
        end
    end
    return first
end

-- A big floor lit flat by the sun reads as a blank sheet, whatever colour it
-- is painted. A darker inlay inside each room, and a seam along the cell grid,
-- give the eye something to measure the space by.
local function floorDetail(model: Model, plan, analysis, theme)
    local gw, gd, floors = MapPlan.Size(plan)
    for f = 1, floors do
        local base = (f - 1) * MapPlan.FLOOR_HEIGHT
        for z = 1, gd do
            for x = 1, gw do
                local ch = MapPlan.Cell(plan, f, x, z)
                if not MapPlan.IsWalkable(ch) or analysis.ramp[MapPlan.Key(f, x, z)] then
                    continue
                end
                local style = theme.styles[plan.regions[ch].style]
                if not style then
                    continue
                end
                local shade = Color3.fromHex(style.floor)
                local h, s, v = shade:ToHSV()
                local cx, _, cz = MapPlan.Position(plan, f, x, z)
                -- A seam on the cell's own edges, drawn just proud of the floor.
                -- The cross seam stops short of the corners, where it would lie
                -- on the neighbouring cell's seam and flicker.
                for _, seam in { { CELL, 0.6, 0, CELL / 2 }, { 0.6, CELL - 1.2, CELL / 2, 0 } } do
                    deco(
                        "FloorSeam",
                        model,
                        Vector3.new(seam[1], 0.08, seam[2]),
                        CFrame.new(cx + seam[3], base + 0.04, cz + seam[4]),
                        Color3.fromHSV(h, s, math.max(0, v * 0.78)),
                        M.SmoothPlastic
                    )
                end
                -- An inlaid panel in the middle of the cell
                deco(
                    "FloorInlay",
                    model,
                    Vector3.new(CELL - 7, 0.06, CELL - 7),
                    CFrame.new(cx, base + 0.03, cz),
                    Color3.fromHSV(h, math.min(1, s * 1.25), math.max(0, v * 0.88)),
                    M.SmoothPlastic
                )
            end
        end
    end
end

---------------------------------------------------------------- Walls, doorways, railings
-- An edge's middle at floor level, the axis it runs along, and the axis that
-- points from its low side (a) to its high side (b)
local function edgeFrame(plan, e): (Vector3, Vector3, Vector3)
    local gw, gd = MapPlan.Size(plan)
    local base = (e.floor - 1) * H
    if e.axis == "x" then
        return Vector3.new(lineAt(e.line, gw), base, lineAt(e.index - 0.5, gd)),
            Vector3.zAxis,
            Vector3.xAxis
    end
    return Vector3.new(lineAt(e.index - 0.5, gw), base, lineAt(e.line, gd)),
        Vector3.xAxis,
        Vector3.zAxis
end

-- Walls facing the outdoors are finished like the shell
local function look(plan, e): string
    if e.kind == "railing" then
        return "railing"
    elseif e.kind == "exterior" then
        return "shell"
    end
    local ra, rb = plan.regions[e.a], plan.regions[e.b]
    if (ra and ra.outdoor) or (rb and rb.outdoor) then
        return "shell"
    end
    return "wall"
end

local function finish(theme, lookName: string): (number, Color3, Enum.Material)
    if lookName == "shell" then
        return SHELL, Color3.fromHex(theme.shell), theme.shellMaterial
    end
    return WALL, Color3.fromHex(theme.wall), theme.wallMaterial
end

-- Where a wall stands, measured from its floor surface: from the middle of
-- its own slab to the middle of the slab above, so both ends are buried.
-- Built from the floor surface up to the storey line instead, a wall's top
-- face lay in the very plane of the floor above, and wherever nothing stood
-- on it upstairs the two z-fought - a flickering line of brick through the
-- floor along every wall below, reading as a floor that had sunk. Ended at
-- the slab's underside it would flicker with the ceiling the same way. Where
-- there is no slab - a stairwell, a double-height hall - the storeys' walls
-- meet edge to edge with no bare strip between.
local WALL_BOTTOM, WALL_TOP = -SLAB / 2, H - SLAB / 2

-- `grounded` is false for a stretch with no floor at its foot: the shell
-- carrying on past a stairwell or a double-height room.
local function solidWall(
    model: Model,
    theme,
    lookName: string,
    mid: Vector3,
    along: Vector3,
    length: number,
    grounded: boolean
)
    local t, colour, material = finish(theme, lookName)
    part(
        if lookName == "shell" then "Shell" else "Wall",
        model,
        boxSize(along, length + t, WALL_TOP - WALL_BOTTOM, t),
        CFrame.new(mid + Vector3.new(0, (WALL_BOTTOM + WALL_TOP) / 2, 0)),
        colour,
        material
    )
    if theme.trim then
        local wood = Color3.fromHex(theme.trim)
        -- With a liner, every trim stands proud of the wall skin (0.3 deep); a
        -- cornice flush with the skin face z-fights it and flickers.
        local band = t + (if theme.liner then 1 else 0.4)
        -- A skirting and a dado rail are set by the height of a floor, so they
        -- belong only on a stretch that has one. Carried on past a stairwell
        -- they hung in mid-air along the storey line, reading as a floor that
        -- had dropped away. A cornice belongs to the ceiling and always runs.
        if grounded then
            deco(
                "Skirting",
                model,
                boxSize(along, length, 1, band),
                CFrame.new(mid + Vector3.new(0, 0.5, 0)),
                wood,
                M.Wood
            )
        end
        deco(
            "Cornice",
            model,
            boxSize(along, length, 0.6, band + 0.2),
            CFrame.new(mid + Vector3.new(0, H - SLAB - 0.45, 0)),
            wood,
            M.Wood
        )
        if theme.dado and grounded then
            deco(
                "DadoRail",
                model,
                boxSize(along, length, 0.5, band),
                CFrame.new(mid + Vector3.new(0, 4.2, 0)),
                Color3.fromHex(theme.dado),
                M.Wood
            )
        end
    end
end

local function railing(model: Model, theme, mid: Vector3, along: Vector3, length: number)
    local colour, material = Color3.fromHex(theme.rail), theme.railMaterial
    -- An invisible waist-high barrier: stops a stumble, not a jump, a shot or a look
    local barrier = part(
        "Railing",
        model,
        boxSize(along, length, RAIL_H, 0.5),
        CFrame.new(mid + Vector3.new(0, RAIL_H / 2, 0)),
        colour,
        material
    )
    barrier.Transparency = 1
    barrier.CanQuery = false
    barrier.CastShadow = false
    deco(
        "Handrail",
        model,
        boxSize(along, length + 0.4, 0.35, 0.6),
        CFrame.new(mid + Vector3.new(0, RAIL_H, 0)),
        colour,
        material
    )
    deco(
        "Kickrail",
        model,
        boxSize(along, length, 0.3, 0.4),
        CFrame.new(mid + Vector3.new(0, 0.5, 0)),
        colour,
        material
    )
    local count = math.max(1, math.floor(length / 4))
    for i = 0, count do
        local offset = -length / 2 + i * (length / count)
        deco(
            "Baluster",
            model,
            Vector3.new(0.3, RAIL_H, 0.3),
            CFrame.new(mid + along * offset + Vector3.new(0, RAIL_H / 2, 0)),
            colour,
            material
        )
    end
end

local function doorway(model: Model, plan, theme, e)
    local centre, along = edgeFrame(plan, e)
    local t, colour, material = finish(theme, look(plan, e))
    -- Jambs from the doorway to the cell corner, and a lintel over the gap
    local from, to = DOOR_W / 2, CELL / 2 + t / 2
    for _, sign in { -1, 1 } do
        part(
            "Wall",
            model,
            boxSize(along, to - from, WALL_TOP - WALL_BOTTOM, t),
            CFrame.new(
                centre
                    + along * (sign * (from + to) / 2)
                    + Vector3.new(0, (WALL_BOTTOM + WALL_TOP) / 2, 0)
            ),
            colour,
            material
        )
    end
    part(
        "Lintel",
        model,
        boxSize(along, DOOR_W, WALL_TOP - DOOR_H, t),
        CFrame.new(centre + Vector3.new(0, (DOOR_H + WALL_TOP) / 2, 0)),
        colour,
        material
    )
    local wood = Color3.fromHex(theme.trim or theme.rail)
    -- Proud of the wall skin, never flush with it
    local frameBand = t + (if theme.liner then 1 else 0.5)
    for _, sign in { -1, 1 } do
        deco(
            "DoorFrame",
            model,
            boxSize(along, 0.6, DOOR_H, frameBand),
            CFrame.new(centre + along * (sign * (DOOR_W / 2 - 0.3)) + Vector3.new(0, DOOR_H / 2, 0)),
            wood,
            M.Wood
        )
    end
    deco(
        "DoorFrame",
        model,
        boxSize(along, DOOR_W, 0.6, frameBand),
        CFrame.new(centre + Vector3.new(0, DOOR_H - 0.3, 0)),
        wood,
        M.Wood
    )
    if e.lockdown then
        -- EventService swings these shut for a Lockdown
        local door = part(
            "Door",
            model,
            boxSize(along, DOOR_W, DOOR_H, 0.6),
            CFrame.new(centre + Vector3.new(0, DOOR_H / 2, 0)),
            Color3.fromHex("5b3a24"),
            M.Wood
        )
        door.CanCollide = false
        door.Transparency = 1
        door:AddTag("LockdownDoor")
    end
end

local function edges(model: Model, plan, analysis, theme)
    local run = nil
    local function flush()
        if not run then
            return
        end
        local centre, along = edgeFrame(plan, run.edge)
        local length = run.count * CELL
        local mid = centre + along * ((run.count - 1) * CELL / 2)
        if run.look == "railing" then
            railing(model, theme, mid, along, length)
        else
            solidWall(model, theme, run.look, mid, along, length, run.grounded)
        end
        run = nil
    end
    for _, e in analysis.edges do
        if e.kind == "door" then
            flush()
            doorway(model, plan, theme, e)
        elseif e.kind == "open" then
            flush()
        else
            local lookName = look(plan, e)
            -- Nobody stands at the foot of a wall with a hole on both sides of
            -- it: the shell carrying on past a stairwell. A run breaks where
            -- that changes, so its trim is right along its whole length.
            local grounded = MapPlan.IsWalkable(e.a) or MapPlan.IsWalkable(e.b)
            if
                run
                and run.look == lookName
                and run.grounded == grounded
                and run.edge.floor == e.floor
                and run.edge.axis == e.axis
                and run.edge.line == e.line
                and run.last + 1 == e.index
            then
                run.count += 1
                run.last = e.index
            else
                flush()
                run = { edge = e, count = 1, last = e.index, look = lookName, grounded = grounded }
            end
        end
    end
    flush()
end

-- Every room paints its own walls: a coloured skin on each face, so a room
-- reads as a room and neighbouring rooms never share a colour by accident
local function skins(model: Model, plan, analysis, theme)
    if not theme.liner then
        return
    end
    local function solid(edge): boolean
        return edge ~= nil
            and (edge.kind == "wall" or edge.kind == "exterior" or edge.kind == "door")
    end
    local function edgeAt(f: number, axis: string, line: number, index: number)
        return analysis.byId[MapPlan.EdgeId(f, axis, line, index)]
    end
    -- How far past the cell corner this side's skin must run at one end of
    -- the wall. Every wall is built half a thickness long at each end so two
    -- meeting at a corner close it, and inside a room that overlap is buried
    -- in the other wall. Where the wall turns away from this room instead -
    -- the inside corner of an L-shaped corridor - or stops at a railing or
    -- open floor, that stub stands out into the room with its bare brick
    -- showing, so the skin runs on to wrap it.
    local function extension(e, side, low: boolean): (number, boolean)
        local ax, az, bx, bz = MapPlan.EdgeCells(e)
        local cx, cz, ox, oz = ax, az, bx, bz
        if side.face > 0 then
            cx, cz, ox, oz = bx, bz, ax, az
        end
        local own, other, onward
        if e.axis == "x" then
            local vz = if low then e.index - 1 else e.index
            own = edgeAt(e.floor, "z", vz, cx)
            other = edgeAt(e.floor, "z", vz, ox)
            onward = edgeAt(e.floor, "x", e.line, if low then e.index - 1 else e.index + 1)
        else
            local vx = if low then e.index - 1 else e.index
            own = edgeAt(e.floor, "x", vx, cz)
            other = edgeAt(e.floor, "x", vx, oz)
            onward = edgeAt(e.floor, "z", e.line, if low then e.index - 1 else e.index + 1)
        end
        if solid(own) then
            return 0, false
        end
        if solid(onward) then
            -- The wall carries straight on. Where a shell gives way to a
            -- thinner wall its stub reaches half a shell past the corner,
            -- and its face lands exactly flush with the thin wall's skin,
            -- flickering. The thicker skin runs on over the stub instead.
            local t = finish(theme, look(plan, e))
            local onwardT = finish(theme, look(plan, onward))
            return if onwardT < t then t / 2 else 0, false
        end
        if solid(other) then
            -- Reach the outer face of the skin on the wall the corner turns into
            local t = finish(theme, look(plan, other))
            return t / 2 + 0.45, false
        end
        local t = finish(theme, look(plan, e))
        return t / 2, true
    end
    for _, e in analysis.edges do
        if e.kind ~= "exterior" and e.kind ~= "wall" and e.kind ~= "door" then
            continue
        end
        local centre, along, across = edgeFrame(plan, e)
        -- The wall this edge actually got: an interior edge beside an outdoor
        -- region is built shell-thick, and a skin sized for a thin wall would
        -- sit inside it with its face flush to the wall's, flickering.
        local thickness = finish(theme, look(plan, e))
        local ax, az, bx, bz = MapPlan.EdgeCells(e)
        local sides = {
            { ch = e.a, face = -1, x = ax, z = az },
            { ch = e.b, face = 1, x = bx, z = bz },
        }
        local capped = false
        for _, side in sides do
            -- A ^ cell is the head of the room below, so line the wall in that
            -- room's colour. Skipping it left the bare shell facing indoors:
            -- across a stairwell you looked at raw exterior brick starting at
            -- the storey line, which reads as a floor that has dropped away.
            local below = if side.ch == "^"
                then MapPlan.OpensInto(plan, e.floor, side.x, side.z)
                else nil
            local ch: string = below or side.ch
            local region = plan.regions[ch]
            if not region or region.outdoor then
                continue
            end
            local style = theme.styles[region.style]
            local colour = Color3.fromHex((style and style.wall) or theme.wall)
            local material = (style and style.wallMaterial) or theme.wallMaterial
            local offset = across * side.face * (thickness / 2 + 0.15)
            -- The skin covers the wall's whole height, slab to slab. Its ends
            -- are buried in the slabs where there are any, and where there
            -- are none - a stairwell, a double-height hall - it meets the
            -- skin of the storey above with no bare strip between.
            local bottom, top = WALL_BOTTOM, WALL_TOP
            local extLow, freeLow = extension(e, side, true)
            local extHigh, freeHigh = extension(e, side, false)
            local function panel(from: number, to: number)
                deco(
                    "WallSkin",
                    model,
                    boxSize(along, to - from, top - bottom, 0.3),
                    CFrame.new(
                        centre
                            + offset
                            + along * ((from + to) / 2)
                            + Vector3.new(0, (bottom + top) / 2, 0)
                    ),
                    colour,
                    material
                )
            end
            if e.kind == "door" then
                -- Skin the jambs and the panel over the door too, so a room's
                -- colour runs unbroken past its doorways
                local from, to = DOOR_W / 2, CELL / 2
                panel(-to - extLow, -from)
                panel(from, to + extHigh)
                deco(
                    "WallSkin",
                    model,
                    boxSize(along, DOOR_W, top - DOOR_H, 0.3),
                    CFrame.new(centre + offset + Vector3.new(0, (DOOR_H + top) / 2, 0)),
                    colour,
                    material
                )
            else
                panel(-CELL / 2 - extLow, CELL / 2 + extHigh)
            end
            -- A wall that simply stops - at a railing, or beside open floor -
            -- shows its end. Cap it in the first room's colour, wide enough
            -- to close both side skins.
            for _, at in { { sign = -1, free = freeLow }, { sign = 1, free = freeHigh } } do
                if capped or not at.free then
                    continue
                end
                deco(
                    "WallSkin",
                    model,
                    boxSize(along, 0.3, top - bottom, thickness + 0.9),
                    CFrame.new(
                        centre
                            + along * (at.sign * (CELL / 2 + thickness / 2 + 0.15))
                            + Vector3.new(0, (bottom + top) / 2, 0)
                    ),
                    colour,
                    material
                )
            end
            capped = true
        end
    end
end

---------------------------------------------------------------- Windows
local function windows(model: Model, plan, analysis, theme)
    if not theme.windows then
        return
    end
    local frame = Color3.fromHex(theme.trim or theme.rail)
    for _, e in analysis.edges do
        if e.kind ~= "exterior" or e.floor <= plan.underground or e.index % 2 == 0 then
            continue
        end
        local inside = if MapPlan.IsWalkable(e.a)
            then -1
            elseif MapPlan.IsWalkable(e.b) then 1
            else 0
        local region = plan.regions[if inside < 0 then e.a else e.b]
        if inside == 0 or (region and region.outdoor) then
            continue
        end
        local centre, along, across = edgeFrame(plan, e)
        local inward = across * inside
        local at = centre + inward * (SHELL / 2 + 0.45) + Vector3.new(0, H * 0.5, 0)
        local glass = deco(
            "Window",
            model,
            boxSize(along, 8, 8, 0.2),
            CFrame.new(at),
            Color3.fromHex("aecbe8"),
            M.Glass
        )
        -- Real daytime glass: see partly through it, a glassy sheen, and soft
        -- cool daylight rather than a saturated blue "moonlit" panel. Kept
        -- semi-opaque so a blackout does not blow out through it.
        glass.Transparency = 0.42
        glass.Reflectance = 0.12
        local light = Instance.new("SurfaceLight")
        light.Face = faceToward(inward)
        light.Color = Color3.fromHex("dbe8f7")
        light.Brightness = 1
        light.Range = 22
        light.Angle = 80
        light.Parent = glass
        for _, bar in
            {
                { 9, 0.6, 0, 4.2 },
                { 9, 0.6, 0, -4.2 },
                { 0.6, 9, 4.2, 0 },
                { 0.6, 9, -4.2, 0 },
                { 0.3, 8, 0, 0 },
            }
        do
            deco(
                "WindowFrame",
                model,
                boxSize(along, bar[1], bar[2], 0.5),
                CFrame.new(at + inward * 0.15 + along * bar[3] + Vector3.new(0, bar[4], 0)),
                frame,
                M.Wood
            )
        end
    end
end

---------------------------------------------------------------- Stairs
local function staircase(model: Model, plan, theme, s)
    local base = (s.floor - 1) * H
    local first, last = s.cells[1], s.cells[#s.cells]
    local ax, _, az = MapPlan.Position(plan, s.floor, first.x, first.z)
    local bx, _, bz = MapPlan.Position(plan, s.floor, last.x, last.z)
    local dir = Vector3.new(s.dx, 0, s.dz)
    local run = s.len * CELL
    local centre = Vector3.new((ax + bx) / 2, base, (az + bz) / 2)
    local wood = Color3.fromHex(theme.stair)

    -- Real steps rather than a ramp: a humanoid walks up a 0.8-stud riser
    -- without jumping, pathfinding reads them, and the top lands flush with
    -- the floor above
    local steps = s.len * 10
    local rise, depth = H / steps, run / steps
    local bottom = centre - dir * (run / 2)
    for i = 1, steps do
        local height = i * rise
        local at = bottom + dir * ((i - 0.5) * depth) + Vector3.new(0, height / 2, 0)
        part(
            "Step",
            model,
            if dir.X ~= 0
                then Vector3.new(depth, height, STAIR_W)
                else Vector3.new(STAIR_W, height, depth),
            CFrame.new(at),
            wood,
            floorMaterialFor(theme.stair, theme.stairMaterial)
        )
    end

    -- A banister down each side, so nobody walks off the steps
    local slope = dir * run + Vector3.new(0, H, 0)
    local side = Vector3.new(-s.dz, 0, s.dx)
    for _, sign in { -1, 1 } do
        local mid = centre
            + side * (sign * (STAIR_W / 2 + 0.3))
            + Vector3.new(0, H / 2 + RAIL_H / 2, 0)
        local banister = part(
            "Banister",
            model,
            Vector3.new(0.5, RAIL_H, slope.Magnitude),
            CFrame.lookAt(mid, mid + slope.Unit),
            Color3.fromHex(theme.rail),
            theme.railMaterial
        )
        banister.CanQuery = false
    end
end

---------------------------------------------------------------- Lamps
local function lamps(model: Model, plan, analysis, theme)
    local gw, gd, floors = MapPlan.Size(plan)
    local colour = Color3.fromHex(theme.lamp)
    local count = 0

    local function light(lamp: BasePart, range: number)
        count += 1
        lamp:AddTag("MapLight")
        local l = Instance.new("PointLight")
        l.Color = colour
        l.Range = range
        l.Brightness = 1.5
        l.Shadows = count % 3 == 0 -- a few shadow casters keep phones smooth
        l.Parent = lamp
    end

    local function hang(f: number, x: number, z: number, drop: number, range: number)
        local cx, base, cz = MapPlan.Position(plan, f, x, z)
        local ceiling = base + H - SLAB
        local y = ceiling - drop
        -- A warm bulb under a shade, not a bare glowing cube. The bulb keeps the
        -- MapLight tag (light() tags it) so Lights Out still douses it.
        local bulb =
            deco("Lamp", model, Vector3.new(1, 1, 1), CFrame.new(cx, y, cz), colour, M.Neon)
        bulb.Shape = Enum.PartType.Ball
        deco(
            "LampShade",
            model,
            Vector3.new(2.1, 0.45, 2.1),
            CFrame.new(cx, y + 0.6, cz),
            Color3.fromHex("2a2018"),
            M.Metal
        )
        deco(
            "LampCord",
            model,
            Vector3.new(0.15, drop - 0.3, 0.15),
            CFrame.new(cx, (ceiling + y + 0.85) / 2, cz),
            Color3.fromHex("1a1a1a"),
            M.Metal
        )
        light(bulb, range)
    end

    local lit, fallback = {}, {}
    for f = 1, floors do
        for z = 1, gd do
            for x = 1, gw do
                local ch = MapPlan.Cell(plan, f, x, z)
                local key = MapPlan.Key(f, x, z)
                if ch == "^" then
                    -- Chandeliers down the middle of double-height rooms
                    if analysis.roof[key] and x % 2 == 0 and z % 2 == 0 then
                        hang(f, x, z, 3, 44)
                    end
                    continue
                end
                if not MapPlan.IsWalkable(ch) or analysis.ramp[key] then
                    continue
                end
                local region = plan.regions[ch]
                if region.outdoor then
                    -- Lamp posts along the railings, every third cell
                    if (x + z) % 3 ~= 0 then
                        continue
                    end
                    for _, side in SIDES do
                        if MapPlan.EdgeKind(analysis, f, x, z, side) == "railing" then
                            local d = MapPlan.DIRS[side]
                            local cx, base, cz = MapPlan.Position(plan, f, x, z)
                            local at = Vector3.new(cx, base, cz)
                                + Vector3.new(d[1], 0, d[2]) * (CELL / 2 - 1.2)
                            local post = part(
                                "LampPost",
                                model,
                                Vector3.new(0.6, 10, 0.6),
                                CFrame.new(at + Vector3.new(0, 5, 0)),
                                Color3.fromHex("2b2f33"),
                                M.Metal
                            )
                            post.CanQuery = false
                            local lamp = deco(
                                "Lamp",
                                model,
                                Vector3.new(1.3, 1.3, 1.3),
                                CFrame.new(at + Vector3.new(0, 10.3, 0)),
                                colour,
                                M.Neon
                            )
                            lamp.Shape = Enum.PartType.Ball
                            deco(
                                "LampCap",
                                model,
                                Vector3.new(1.7, 0.4, 1.7),
                                CFrame.new(at + Vector3.new(0, 11.15, 0)),
                                Color3.fromHex("2b2f33"),
                                M.Metal
                            )
                            light(lamp, 36)
                            break
                        end
                    end
                    continue
                end
                local covered = analysis.roof[key]
                    or MapPlan.IsWalkable(MapPlan.Cell(plan, f + 1, x, z))
                if not covered then
                    continue
                end
                local group = f .. ch
                fallback[group] = fallback[group] or { x = x, z = z }
                if x % 2 == 1 and z % 2 == 1 then
                    hang(f, x, z, 1.6, 30)
                    lit[group] = true
                end
            end
        end
    end
    -- Every room gets at least one light
    for group, cell in fallback do
        if not lit[group] then
            hang(tonumber(string.match(group, "^%d+")) :: number, cell.x, cell.z, 1.6, 30)
        end
    end
end

---------------------------------------------------------------- Furniture and dressing
local function dressRooms(
    model: Model,
    plan,
    analysis,
    theme,
    reserved: { [string]: boolean },
    rng: Random
)
    local folder = ServerStorage:FindFirstChild("Props")
    local gw, gd, floors = MapPlan.Size(plan)

    local function template(name: string?): Model?
        local t = folder and name and folder:FindFirstChild(name)
        return if t and t:IsA("Model") then t else nil
    end

    local function place(t: Model, cf: CFrame)
        local prop = t:Clone()
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

    local function rug(cf: CFrame, colourHex: string)
        local colour = Color3.fromHex(colourHex)
        local h, s, v = colour:ToHSV()
        deco(
            "RugBorder",
            model,
            Vector3.new(15.2, 0.1, 11.2),
            cf * CFrame.new(0, 0.05, 0),
            Color3.fromHSV(h, s, v * 0.55),
            M.Fabric
        )
        deco("Rug", model, Vector3.new(14, 0.14, 10), cf * CFrame.new(0, 0.07, 0), colour, M.Fabric)
    end

    -- Pass one: each standable cell's four edges, and each room's most open cell
    local cells = {}
    local centreCell = {}
    for f = 1, floors do
        for z = 1, gd do
            for x = 1, gw do
                local ch = MapPlan.Cell(plan, f, x, z)
                local key = MapPlan.Key(f, x, z)
                if not MapPlan.IsWalkable(ch) or analysis.ramp[key] or analysis.approach[key] then
                    continue
                end
                local kinds, passage, rail, openSides = {}, false, false, 0
                for _, side in SIDES do
                    local kind = MapPlan.EdgeKind(analysis, f, x, z, side)
                    kinds[side] = kind
                    passage = passage or kind == "door" or kind == "open"
                    rail = rail or kind == "railing"
                    if kind == "none" then
                        openSides += 1
                    end
                end
                local info = {
                    f = f,
                    x = x,
                    z = z,
                    ch = ch,
                    kinds = kinds,
                    passage = passage,
                    rail = rail,
                    openSides = openSides,
                }
                table.insert(cells, info)
                local style = theme.styles[plan.regions[ch].style]
                if style and style.centre and not passage and not rail and not reserved[key] then
                    local group = f .. ch
                    local best = centreCell[group]
                    if not best or openSides > best.openSides then
                        centreCell[group] = { info = info, openSides = openSides }
                    end
                end
            end
        end
    end

    -- Pass two: centrepieces, pieces against walls, paintings
    for _, info in cells do
        local region = plan.regions[info.ch]
        local style = theme.styles[region.style]
        if not style then
            continue
        end
        local cx, base, cz = MapPlan.Position(plan, info.f, info.x, info.z)
        local against: { [string]: boolean } = {}

        local best = centreCell[info.f .. info.ch]
        local centrepiece = best and best.info == info and template(style.centre)
        if centrepiece then
            local size = centrepiece:GetExtentsSize()
            local turn = CFrame.Angles(0, if rng:NextNumber() < 0.5 then 0 else math.pi / 2, 0)
            local cf = CFrame.new(cx, base + size.Y / 2, cz) * turn
            place(centrepiece, cf)
            if style.rug then
                rug(CFrame.new(cx, base, cz) * turn, style.rug)
            end
            local chair = style.chairs and template("DiningChair")
            if chair then
                local chairSize = chair:GetExtentsSize()
                for _, spot in { { -0.25, 1 }, { 0.25, 1 }, { -0.25, -1 }, { 0.25, -1 } } do
                    local at = cf:PointToWorldSpace(
                        Vector3.new(
                            size.X * spot[1],
                            0,
                            spot[2] * (size.Z / 2 + chairSize.Z / 2 + 0.6)
                        )
                    )
                    at = Vector3.new(at.X, base + chairSize.Y / 2, at.Z)
                    place(chair, CFrame.lookAt(at, Vector3.new(cx, at.Y, cz)))
                end
            end
        elseif
            not info.passage
            and (style.againstRail or not info.rail)
            and #style.props > 0
            and rng:NextNumber() < math.min(0.9, (style.density or 0) * 1.25)
        then
            -- One piece with its back to a wall (or a railing, outdoors)
            -- Random has NextInteger but is nominally typed, so it does not
            -- match Shuffle.Generator structurally. The seed still decides the
            -- order, which is what keeps a map dressing itself the same way.
            local order = Shuffle.Shuffled(SIDES, rng :: any)
            for _, side in order do
                local kind = info.kinds[side]
                if
                    not (
                        kind == "wall"
                        or kind == "exterior"
                        or (style.againstRail and kind == "railing")
                    )
                then
                    continue
                end
                local t = template(style.props[rng:NextInteger(1, #style.props)])
                if t then
                    local size = t:GetExtentsSize()
                    local d = MapPlan.DIRS[side]
                    local out = Vector3.new(d[1], 0, d[2])
                    local along = Vector3.new(-d[2], 0, d[1])
                    local thickness = if kind == "exterior"
                        then SHELL
                        elseif kind == "railing" then 0.6
                        else WALL
                    -- A spawn pad or coin sits in the middle of a reserved
                    -- cell; a deep piece (a bed, a crate stack) with its
                    -- back to the wall would reach into it, so try another
                    if
                        reserved[MapPlan.Key(info.f, info.x, info.z)]
                        and CELL / 2 - thickness / 2 - size.Z - 0.3 < RESERVED_CLEAR
                    then
                        continue
                    end
                    local slack = math.max(0, CELL / 2 - size.X / 2 - 2)
                    local at = Vector3.new(cx, base + size.Y / 2, cz)
                        + out * (CELL / 2 - thickness / 2 - size.Z / 2 - 0.3)
                        + along * rng:NextNumber(-slack, slack)
                    place(t, CFrame.lookAt(at, at - out))
                    against[side] = true
                end
                break
            end
        end

        -- A working room is full: crates and stock stand out on the floor too,
        -- but only in cells open on all four sides, so every piece can be
        -- walked around
        if
            style.clutter
            and not centrepiece
            and info.openSides == 4
            and next(against) == nil
            and not reserved[MapPlan.Key(info.f, info.x, info.z)]
            and #style.props > 0
            and rng:NextNumber() < style.clutter
        then
            local piece = template(style.props[rng:NextInteger(1, #style.props)])
            if piece then
                local size = piece:GetExtentsSize()
                local at = Vector3.new(
                    cx + rng:NextNumber(-3.5, 3.5),
                    base + size.Y / 2,
                    cz + rng:NextNumber(-3.5, 3.5)
                )
                place(piece, CFrame.new(at) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
            end
        end

        -- Pictures on the walls: interior walls, and exterior walls with no
        -- window on them (windows hang on every other exterior edge, above
        -- ground). Each sits on the room face of the wall skin, frame slab
        -- behind and canvas proud of it, never over a doorway, never where
        -- furniture stands against the wall.
        local pics = theme.pictures
        if pics and not region.outdoor then
            for _, side in SIDES do
                local kind = info.kinds[side]
                if kind ~= "wall" and kind ~= "exterior" then
                    continue
                end
                if against[side] or rng:NextNumber() > pics.chance then
                    continue
                end
                local edge = analysis.byId[MapPlan.SideEdgeId(info.f, info.x, info.z, side)]
                local windowed = kind == "exterior"
                    and theme.windows
                    and info.f > plan.underground
                    and edge ~= nil
                    and edge.index % 2 == 1
                if windowed then
                    continue
                end
                local d = MapPlan.DIRS[side]
                local out = Vector3.new(d[1], 0, d[2])
                local along = Vector3.new(-d[2], 0, d[1])
                -- The wall this edge was actually built with (an interior
                -- edge beside an outdoor region is shell-thick), and so
                -- the skin's room face, measured from the cell centre
                local t = if edge then finish(theme, look(plan, edge)) else WALL
                local skinFace = CELL / 2 - t / 2 - 0.3
                local frameDepth, canvasDepth = 0.35, 0.12
                local frameAt = Vector3.new(cx, base + 7.5, cz)
                    + out * (skinFace - frameDepth / 2 + 0.02)
                deco(
                    "PaintingFrame",
                    model,
                    boxSize(along, pics.width, pics.height, frameDepth),
                    CFrame.new(frameAt),
                    Color3.fromHex(pics.frame),
                    pics.frameMaterial or M.Wood
                )
                local canvasAt = Vector3.new(cx, base + 7.5, cz)
                    + out * (skinFace - frameDepth + 0.02 - canvasDepth / 2)
                deco(
                    "Painting",
                    model,
                    boxSize(along, pics.width - 1, pics.height - 1, canvasDepth),
                    CFrame.new(canvasAt),
                    Color3.fromHex(pics.canvases[rng:NextInteger(1, #pics.canvases)])
                )
            end
        end

        -- A bin in an inside corner: two solid sides meeting, no furniture
        -- against either, never a spawn or coin cell. It stands on the floor
        -- and clear of both skins, and a corner is never a doorway.
        -- Outdoors it stands where a railing corner would hold it, on the
        -- decks and roofs that also take furniture against a rail.
        local bin = theme.bin
        if
            bin
            and (not region.outdoor or style.againstRail)
            and not reserved[MapPlan.Key(info.f, info.x, info.z)]
            and rng:NextNumber() < (if region.hall then 0.5 else 0.3)
        then
            local corners = { { "N", "E" }, { "E", "S" }, { "S", "W" }, { "W", "N" } }
            local open = {}
            for _, c in corners do
                local k1, k2 = info.kinds[c[1]], info.kinds[c[2]]
                local function solidSide(k)
                    return k == "wall"
                        or k == "exterior"
                        or k == "door"
                        or (region.outdoor and k == "railing")
                end
                if solidSide(k1) and solidSide(k2) and not against[c[1]] and not against[c[2]] then
                    table.insert(open, c)
                end
            end
            if #open > 0 then
                local c = open[rng:NextInteger(1, #open)]
                local r = bin.diameter / 2
                local at = Vector3.new(cx, base + bin.height / 2, cz)
                for _, side in c do
                    local d = MapPlan.DIRS[side]
                    local edge = analysis.byId[MapPlan.SideEdgeId(info.f, info.x, info.z, side)]
                    local t = if info.kinds[side] == "railing"
                        then 0.6
                        elseif edge then finish(theme, look(plan, edge))
                        else WALL
                    local skinFace = CELL / 2 - t / 2 - 0.3
                    at += Vector3.new(d[1], 0, d[2]) * (skinFace - r - 0.35)
                end
                local upright = CFrame.Angles(0, 0, math.rad(90))
                local body = part(
                    "Bin",
                    model,
                    Vector3.new(bin.height, bin.diameter, bin.diameter),
                    CFrame.new(at) * upright,
                    Color3.fromHex(bin.colour),
                    bin.material
                )
                body.Shape = Enum.PartType.Cylinder
                local rim = deco(
                    "BinRim",
                    model,
                    Vector3.new(0.3, bin.diameter + 0.3, bin.diameter + 0.3),
                    CFrame.new(at.X, base + bin.height - 0.15, at.Z) * upright,
                    Color3.fromHex(bin.rim),
                    bin.rimMaterial
                )
                rim.Shape = Enum.PartType.Cylinder
                if bin.lid then
                    local lid = deco(
                        "BinLid",
                        model,
                        Vector3.new(0.25, bin.diameter + 0.2, bin.diameter + 0.2),
                        CFrame.new(at.X, base + bin.height + 0.125, at.Z) * upright,
                        Color3.fromHex(bin.rim),
                        bin.rimMaterial
                    )
                    lid.Shape = Enum.PartType.Cylinder
                    deco(
                        "BinLid",
                        model,
                        Vector3.new(0.6, 0.4, 0.6),
                        CFrame.new(at.X, base + bin.height + 0.45, at.Z),
                        Color3.fromHex(bin.rim),
                        bin.rimMaterial
                    )
                end
            end
        end
    end
end

---------------------------------------------------------------- Waterfront
-- Rusted Pier stands on pilings over open water
local function waterfront(model: Model, plan)
    local gw, gd = MapPlan.Size(plan)
    local water = deco(
        "Water",
        model,
        Vector3.new(gw * CELL + 1000, 1, gd * CELL + 1000),
        CFrame.new(0, -4, 0),
        Color3.fromHex("2f86c4"),
        M.Glass
    )
    water.Transparency = 0.28
    water.Reflectance = 0.15

    -- Corners of the boardwalk get short pilings; corners under the deck where
    -- no boardwalk stands get tall ones
    local posts: { [string]: boolean } = {}
    for z = 1, gd do
        for x = 1, gw do
            local low = MapPlan.IsWalkable(MapPlan.Cell(plan, 1, x, z))
            local high = MapPlan.Cell(plan, 2, x, z) ~= "."
            if low or high then
                for _, c in { { x - 1, z - 1 }, { x, z - 1 }, { x - 1, z }, { x, z } } do
                    local id = c[1] .. ":" .. c[2]
                    posts[id] = (posts[id] or false) or low
                end
            end
        end
    end
    local wood = Color3.fromHex("3a2f24")
    for id, short in posts do
        local cx, cz = string.match(id, "^(%-?%d+):(%-?%d+)$")
        local top = if short then -SLAB else H - SLAB
        local bottom = -12
        deco(
            "Piling",
            model,
            Vector3.new(1.2, top - bottom, 1.2),
            CFrame.new(
                lineAt(tonumber(cx) :: number, gw),
                (top + bottom) / 2,
                lineAt(tonumber(cz) :: number, gd)
            ),
            wood,
            M.Wood
        )
    end
end

---------------------------------------------------------------- Build
local function build(mapName: string, plan, theme): Model
    local model = Instance.new("Model")
    model.Name = mapName
    local analysis = MapPlan.Analyse(plan)
    for _, problem in analysis.problems do
        warn(("[ColdCase] %s plan: %s"):format(mapName, problem))
    end

    model.PrimaryPart = slabs(model, plan, analysis, theme)
    edges(model, plan, analysis, theme)
    floorDetail(model, plan, analysis, theme)
    skins(model, plan, analysis, theme)
    windows(model, plan, analysis, theme)
    for _, s in analysis.stairs do
        staircase(model, plan, theme, s)
    end
    lamps(model, plan, analysis, theme)
    if theme.water then
        waterfront(model, plan)
    end

    local points = MapPlan.Points(plan, analysis)
    local reserved = {}
    for i, c in points.spawns do
        reserved[MapPlan.Key(c.f, c.x, c.z)] = true
        local x, y, z = MapPlan.Position(plan, c.f, c.x, c.z)
        local p = part(
            ("Spawn_%02d"):format(i),
            model,
            Vector3.new(8, 0.4, 8),
            CFrame.new(x, y + 0.2, z),
            Color3.fromHex("37bcf0")
        )
        -- A marker, not scenery: invisible, and never in the way of a shot
        p.CanCollide = false
        p.CanQuery = false
        p.Transparency = 1
        p:AddTag("SpawnPoint")
    end
    for i, c in points.coins do
        reserved[MapPlan.Key(c.f, c.x, c.z)] = true
        local x, y, z = MapPlan.Position(plan, c.f, c.x, c.z)
        -- A real coin, not a flat marker: a thin gold disc stood on edge, its
        -- round faces pointing along X so it shows a face then its edge as the
        -- client spins it. Still Neon so it stays findable across a dark room.
        local p = part(
            ("Coin_%02d"):format(i),
            model,
            Vector3.new(0.4, 2.2, 2.2),
            CFrame.new(x, y + 2.7, z),
            Color3.fromHex("f2a63b"),
            M.Neon
        )
        p.Shape = Enum.PartType.Cylinder
        p.CanCollide = false
        p.CanQuery = false
        p:SetAttribute("NodeId", i)
        p:AddTag("CoinNode")
    end

    dressRooms(model, plan, analysis, theme, reserved, Random.new(#mapName * 7919))
    return model
end

return function(opts: { force: boolean? }?)
    local force = opts and opts.force

    -- A Maps folder saved into the place file is generated code that has
    -- stopped tracking its generator. Reused blindly, every later change in
    -- this file is ignored in silence and the maps keep the shape they had
    -- when they were baked - a geometry fix can be written, reviewed, merged
    -- and published without ever reaching the game. So a baked folder is kept
    -- only while it still belongs to the running place; republish and it is
    -- rebuilt. A folder built at run time never outlives its server.
    -- An unpublished place (Studio, a local file, the test build) has place
    -- version 0 forever, so a folder saved into it would match on every start
    -- and never be rebuilt: the walkthrough of 2026-09-22 found a place file
    -- carrying maps baked before the furniture existed, so no round ever had
    -- any. Only a published server may keep a folder, and only its own.
    local folder = ServerStorage:FindFirstChild("Maps")
    if
        folder
        and not force
        and game.PlaceVersion > 0
        and folder:GetAttribute("PlaceVersion") == game.PlaceVersion
    then
        return folder
    end
    if folder then
        folder:Destroy()
    end
    folder = Instance.new("Folder")
    folder.Name = "Maps"

    for mapName, plan in MapPlan.MAPS do
        local theme = THEMES[mapName]
        if theme then
            build(mapName, plan, theme).Parent = folder
        else
            warn("[ColdCase] no theme for map " .. mapName)
        end
    end

    if not ServerStorage:FindFirstChild("BodyTemplate") then
        -- A body reads as a person, not a red brick: a figure collapsed on its
        -- back, head, torso, two arms and two legs in skin and clothing tones,
        -- lying flat with a little asymmetry so it looks fallen, not laid out.
        -- Cloned whole by EvidenceService and dropped at the death spot; the
        -- Torso stays the PrimaryPart so the existing pivot maths is unchanged.
        local body = Instance.new("Model")
        body.Name = "BodyTemplate"
        local SKIN = Color3.fromHex("e0a878")
        local SHIRT = Color3.fromHex("59616e")
        local PANTS = Color3.fromHex("32363c")
        local limbs: { BasePart } = {}
        local function limb(name: string, size: Vector3, cf: CFrame, colour: Color3)
            local p = part(name, body, size, cf, colour)
            table.insert(limbs, p)
            return p
        end
        -- The figure lies along Z: head toward -Z, feet toward +Z, thin in Y.
        local torso = limb("Torso", Vector3.new(2, 0.9, 2.7), CFrame.new(0, 0.5, 0), SHIRT)
        limb("Head", Vector3.new(1.3, 1.2, 1.3), CFrame.new(0.15, 0.55, -2.1), SKIN).Shape =
            Enum.PartType.Ball
        limb(
            "ArmLeft",
            Vector3.new(0.7, 0.65, 2.3),
            CFrame.new(-1.35, 0.45, -0.4) * CFrame.Angles(0, math.rad(18), 0),
            SKIN
        )
        limb(
            "ArmRight",
            Vector3.new(0.7, 0.65, 2.3),
            CFrame.new(1.4, 0.45, 0.2) * CFrame.Angles(0, math.rad(-9), 0),
            SKIN
        )
        limb(
            "LegLeft",
            Vector3.new(0.8, 0.75, 2.7),
            CFrame.new(-0.55, 0.45, 2.6) * CFrame.Angles(0, math.rad(11), 0),
            PANTS
        )
        limb(
            "LegRight",
            Vector3.new(0.8, 0.75, 2.7),
            CFrame.new(0.65, 0.45, 2.5) * CFrame.Angles(0, math.rad(-6), 0),
            PANTS
        )
        for _, p in limbs do
            p.CanCollide = false
        end
        body.PrimaryPart = torso
        body.Parent = ServerStorage
    end

    folder:SetAttribute("PlaceVersion", game.PlaceVersion)
    folder.Parent = ServerStorage
    return folder
end
