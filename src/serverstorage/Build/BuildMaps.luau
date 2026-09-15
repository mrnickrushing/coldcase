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
local STAIR_W = CELL - 4
local M = Enum.Material
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
        ceilingMaterial = M.SmoothPlastic,
        rail = "8a5a3a",
        railMaterial = M.Wood,
        stair = "a9855c",
        stairMaterial = M.SmoothPlastic,
        lamp = "ffe0a8",
        windows = true,
        paintings = true,
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
        shellMaterial = M.SmoothPlastic,
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
        shellMaterial = M.SmoothPlastic,
        roof = "6a6f74",
        roofMaterial = M.Concrete,
        trim = "f4f0e4",
        dado = "8a6a44",
        liner = true,
        ceiling = "f4f2ea",
        ceilingMaterial = M.SmoothPlastic,
        rail = "9aa4ac",
        railMaterial = M.Metal,
        stair = "d8d2c4",
        stairMaterial = M.SmoothPlastic,
        lamp = "ffeccf",
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
                style.floorMaterial
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
                    local ch = MapPlan.Cell(plan, f, x, z)
                    if not MapPlan.IsWalkable(ch) or plan.regions[ch].outdoor then
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
                -- A seam on the cell's own edges, drawn just proud of the floor
                for _, seam in { { CELL, 0.6, 0, CELL / 2 }, { 0.6, CELL, CELL / 2, 0 } } do
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

local function solidWall(
    model: Model,
    theme,
    lookName: string,
    mid: Vector3,
    along: Vector3,
    length: number
)
    local t, colour, material = finish(theme, lookName)
    part(
        if lookName == "shell" then "Shell" else "Wall",
        model,
        boxSize(along, length + t, H, t),
        CFrame.new(mid + Vector3.new(0, H / 2, 0)),
        colour,
        material
    )
    if theme.trim then
        local wood = Color3.fromHex(theme.trim)
        -- Thicker on the shell, so the trim stands proud of the wall lining
        local band = t + (if lookName == "shell" and theme.liner then 1 else 0.4)
        deco(
            "Skirting",
            model,
            boxSize(along, length, 1, band),
            CFrame.new(mid + Vector3.new(0, 0.5, 0)),
            wood,
            M.Wood
        )
        deco(
            "Cornice",
            model,
            boxSize(along, length, 0.6, band + 0.2),
            CFrame.new(mid + Vector3.new(0, H - SLAB - 0.45, 0)),
            wood,
            M.Wood
        )
        if theme.dado then
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
            boxSize(along, to - from, H, t),
            CFrame.new(centre + along * (sign * (from + to) / 2) + Vector3.new(0, H / 2, 0)),
            colour,
            material
        )
    end
    part(
        "Lintel",
        model,
        boxSize(along, DOOR_W, H - DOOR_H, t),
        CFrame.new(centre + Vector3.new(0, (DOOR_H + H) / 2, 0)),
        colour,
        material
    )
    local wood = Color3.fromHex(theme.trim or theme.rail)
    for _, sign in { -1, 1 } do
        deco(
            "DoorFrame",
            model,
            boxSize(along, 0.6, DOOR_H, t + 0.5),
            CFrame.new(centre + along * (sign * (DOOR_W / 2 - 0.3)) + Vector3.new(0, DOOR_H / 2, 0)),
            wood,
            M.Wood
        )
    end
    deco(
        "DoorFrame",
        model,
        boxSize(along, DOOR_W, 0.6, t + 0.5),
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
            solidWall(model, theme, run.look, mid, along, length)
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
            if
                run
                and run.look == lookName
                and run.edge.floor == e.floor
                and run.edge.axis == e.axis
                and run.edge.line == e.line
                and run.last + 1 == e.index
            then
                run.count += 1
                run.last = e.index
            else
                flush()
                run = { edge = e, count = 1, last = e.index, look = lookName }
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
    for _, e in analysis.edges do
        if e.kind ~= "exterior" and e.kind ~= "wall" then
            continue
        end
        local centre, along, across = edgeFrame(plan, e)
        for _, side in { { ch = e.a, face = -1 }, { ch = e.b, face = 1 } } do
            local region = plan.regions[side.ch]
            if not MapPlan.IsWalkable(side.ch) or (region and region.outdoor) then
                continue
            end
            local style = theme.styles[region.style]
            local colour = Color3.fromHex((style and style.wall) or theme.wall)
            local thickness = if e.kind == "exterior" then SHELL else WALL
            local at = centre
                + across * side.face * (thickness / 2 + 0.15)
                + Vector3.new(0, (H - SLAB) / 2, 0)
            deco(
                "WallSkin",
                model,
                boxSize(along, CELL, H - SLAB, 0.3),
                CFrame.new(at),
                colour,
                (style and style.wallMaterial) or theme.wallMaterial
            )
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
            Color3.fromHex("6f8fb3"),
            M.Glass
        )
        glass.Transparency = 0.2
        local light = Instance.new("SurfaceLight")
        light.Face = faceToward(inward)
        light.Color = Color3.fromHex("a9c7ff")
        light.Brightness = 1.2
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
            theme.stairMaterial
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
        local lamp =
            deco("Lamp", model, Vector3.new(1.4, 0.6, 1.4), CFrame.new(cx, y, cz), colour, M.Neon)
        deco(
            "LampCord",
            model,
            Vector3.new(0.15, drop - 0.3, 0.15),
            CFrame.new(cx, (ceiling + y + 0.3) / 2, cz),
            Color3.fromHex("1a1a1a"),
            M.Metal
        )
        light(lamp, range)
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
                                Vector3.new(1.4, 0.8, 1.4),
                                CFrame.new(at + Vector3.new(0, 10.4, 0)),
                                colour,
                                M.Neon
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

        -- Framed paintings on the bare inside walls of rooms
        if theme.paintings and not region.outdoor then
            for _, side in SIDES do
                if info.kinds[side] ~= "wall" or against[side] or rng:NextNumber() > 0.3 then
                    continue
                end
                local d = MapPlan.DIRS[side]
                local out = Vector3.new(d[1], 0, d[2])
                local along = Vector3.new(-d[2], 0, d[1])
                local at = Vector3.new(cx, base + 7.5, cz) + out * (CELL / 2 - WALL / 2 - 0.2)
                deco(
                    "PaintingFrame",
                    model,
                    boxSize(along, 7, 5.5, 0.3),
                    CFrame.new(at),
                    Color3.fromHex("8a6a2e"),
                    M.Wood
                )
                local canvas = { "7a4a2e", "3e5a4a", "5a3a4a", "8a7a5a", "2e3e5a", "6a2e2e" }
                deco(
                    "Painting",
                    model,
                    boxSize(along, 6, 4.5, 0.12),
                    CFrame.new(at - out * 0.2),
                    Color3.fromHex(canvas[rng:NextInteger(1, #canvas)])
                )
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
        local p = part(
            ("Coin_%02d"):format(i),
            model,
            Vector3.new(2, 2, 0.4),
            CFrame.new(x, y + 3, z),
            Color3.fromHex("f2a63b"),
            M.Neon
        )
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

    local folder = ServerStorage:FindFirstChild("Maps")
    if folder and not force then
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
        local body = Instance.new("Model")
        body.Name = "BodyTemplate"
        local torso = part(
            "Torso",
            body,
            Vector3.new(4, 1, 2),
            CFrame.new(0, 0.5, 0),
            Color3.fromHex("8c3330")
        )
        torso.CanCollide = false
        body.PrimaryPart = torso
        body.Parent = ServerStorage
    end

    folder.Parent = ServerStorage
    return folder
end
