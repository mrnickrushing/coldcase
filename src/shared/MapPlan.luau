--[[
  COLD CASE · map plans. Every map is a building of stacked floors drawn as
  character grids, one character per CELL-stud square. Pure data plus the rules
  that turn it into walls, doorways, railings and stairs, so BuildMaps builds
  from it, the lobby vote cards draw it, and the Lune tests prove that every
  room can be reached.

  One character per cell, floor 1 lowest:
    .       nothing: outside, or solid ground around a cellar
    ^       open to the floor below: a stairwell or a double-height room
    letter  a walkable cell of that region (regions are named per map)

  Neighbouring cells of different regions get a wall with a doorway in every
  straight stretch; a room and the outside get an exterior wall (a railing when
  the region is outdoors); a walkable cell beside a ^ gets a railing.

  A stair climbs from `floor` to the floor above over `len` cells heading `dir`
  from its bottom cell (x, z). The cell before the bottom (the approach) shares
  their region; on the floor above the stair's cells are ^ and the cell past the
  top (the arrival) is walkable.
]]
local MapPlan = {}

MapPlan.CELL = 20 -- studs per plan cell
MapPlan.FLOOR_HEIGHT = 16 -- studs from one floor to the next
MapPlan.SPAWNS = 14 -- a full server is 12; the extra two keep the spread honest
MapPlan.COINS = 18

export type Region = { name: string, style: string, hall: boolean?, outdoor: boolean? }
export type Stair = { floor: number, x: number, z: number, dir: string, len: number }
export type Plan = {
    indoor: boolean,
    underground: number, -- floors below ground level, which get no windows
    floors: { { string } },
    regions: { [string]: Region },
    stairs: { Stair },
}

MapPlan.DIRS = {
    N = { 0, -1 },
    S = { 0, 1 },
    E = { 1, 0 },
    W = { -1, 0 },
}

MapPlan.MAPS = {
    BlackwoodManor = {
        indoor = true,
        underground = 1,
        floors = {
            { -- Cellar
                "............",
                "............",
                "............",
                "WWWccccccc..",
                "WWWc.....cTT",
                "WWWc.....cTT",
                "XXXcccccccTT",
                "XXX.........",
            },
            { -- Ground floor
                "LLLLhGGGhDDD",
                "LLLLhGGGhDDD",
                "LLLLhGGGhDDD",
                "hhhhhGGGhhhh",
                "PPPPhGGGhKK^",
                "PPPPhGGGhKK^",
                "SSSShGGGhKKK",
                "S^^ShGGGhBBB",
            },
            { -- Upstairs
                "MMMMgggggRRR",
                "MMMMg^^^gRRR",
                "NNNNg^^^gRRR",
                "gggggggggggg",
                "AAAAg^^^gQQQ",
                "AAAAg^^^gQQQ",
                "CCCCg^^^gQQQ",
                "CCCCggggg^^^",
            },
        },
        regions = {
            W = { name = "Wine Cellar", style = "cellar" },
            c = { name = "Tunnel", style = "tunnel", hall = true },
            X = { name = "Boiler Room", style = "boiler" },
            T = { name = "Coal Store", style = "storage" },
            L = { name = "Library", style = "library" },
            h = { name = "Hallway", style = "hall", hall = true },
            G = { name = "Grand Hall", style = "grandhall", hall = true },
            D = { name = "Dining Room", style = "dining" },
            P = { name = "Parlour", style = "parlour" },
            K = { name = "Kitchen", style = "kitchen" },
            S = { name = "Study", style = "study" },
            B = { name = "Back Stairs", style = "hall", hall = true },
            M = { name = "Master Bedroom", style = "bedroom" },
            N = { name = "Bathroom", style = "bathroom" },
            g = { name = "Gallery", style = "hall", hall = true },
            A = { name = "Bedroom", style = "bedroom" },
            C = { name = "Nursery", style = "bedroom" },
            R = { name = "Guest Room", style = "bedroom" },
            Q = { name = "Billiard Room", style = "parlour" },
        },
        stairs = {
            { floor = 1, x = 12, z = 6, dir = "N", len = 2 }, -- coal store up to the east hall
            { floor = 1, x = 2, z = 8, dir = "E", len = 2 }, -- boiler room up to the study
            { floor = 2, x = 7, z = 6, dir = "N", len = 2 }, -- the grand staircase
            { floor = 2, x = 11, z = 8, dir = "W", len = 2 }, -- the servants' stair
        },
    },

    RustedPier = {
        indoor = false,
        underground = 0,
        floors = {
            { -- Boardwalk under the pier
                "............",
                "............",
                "..BBBBBB....",
                "ppBBBBBBpp..",
                "p.BBBBBB.p..",
                "p.BBBBBB.p..",
                "pppppppppp..",
                ".......ppp..",
            },
            { -- Pier deck and warehouse
                "dddddddddddd",
                "dWWWWWWWWOOd",
                "dWWWWWWWWOOd",
                "dWWWWWWWWbbd",
                "^WWWWWWWWbbd",
                "^WWWWWWWWCCd",
                "dddddddddCCd",
                "...dddd^^dd.",
            },
            { -- Catwalks and roof
                "............",
                ".kkkkkkkkrrr",
                ".kk^^^^^krrr",
                ".k^^^^^^kMr^",
                ".k^^^^^^kMr^",
                ".kkkkkkkkrrr",
                ".........rrr",
                "............",
            },
        },
        regions = {
            p = { name = "Boardwalk", style = "boardwalk", hall = true, outdoor = true },
            B = { name = "Boathouse", style = "boathouse" },
            d = { name = "Pier Deck", style = "deck", hall = true, outdoor = true },
            W = { name = "Warehouse", style = "warehouse", hall = true },
            O = { name = "Harbour Office", style = "office" },
            b = { name = "Break Room", style = "office" },
            C = { name = "Cold Store", style = "coldstore" },
            k = { name = "Catwalk", style = "catwalk", hall = true },
            r = { name = "Roof", style = "roof", hall = true, outdoor = true },
            M = { name = "Foreman's Office", style = "office" },
        },
        stairs = {
            { floor = 1, x = 1, z = 6, dir = "N", len = 2 }, -- boardwalk up through a deck hatch
            { floor = 1, x = 9, z = 8, dir = "W", len = 2 }, -- boardwalk up to the south deck
            { floor = 2, x = 3, z = 5, dir = "N", len = 2 }, -- warehouse up to the catwalks
            { floor = 2, x = 12, z = 5, dir = "N", len = 2 }, -- outside stair up to the roof
        },
    },

    CityArchive = {
        indoor = true,
        underground = 1,
        floors = {
            { -- Vaults
                "............",
                "............",
                "....VVVV....",
                "ccccVVVVcc..",
                "ccccVVVVcc..",
                "cccccccccccc",
                "......WWW.TT",
                "......WWWTTT",
            },
            { -- Ground floor
                "OOOhRRRRhFFF",
                "OOOhRRRRhFFF",
                "hhhhRRRRhhhh",
                "ssshRRRRhttt",
                "s^^hRRRRhttt",
                "hhhhRRRRhhhh",
                "EEEhLLLLhMMM",
                "EEEhLLLLh^^M",
            },
            { -- Stacks
                "AAAggggggBBB",
                "AAAgg^^ggBBB",
                "ggggg^^ggggg",
                "CCCgg^^gg^^D",
                "CCCgg^^ggDDD",
                "gggggggggggg",
                "KKKgNNNNgJJJ",
                "KKKgN^^NgJJJ",
            },
        },
        regions = {
            V = { name = "Vault", style = "vault" },
            c = { name = "Service Corridor", style = "corridor", hall = true },
            W = { name = "Deep Storage", style = "storage" },
            T = { name = "Loading Bay", style = "storage", hall = true },
            O = { name = "Front Office", style = "office" },
            h = { name = "Hallway", style = "hall", hall = true },
            R = { name = "Reading Room", style = "reading", hall = true },
            F = { name = "Records", style = "records" },
            s = { name = "West Stairs", style = "hall", hall = true },
            t = { name = "East Stairs", style = "hall", hall = true },
            E = { name = "Exhibits", style = "exhibits" },
            L = { name = "Lobby", style = "lobby", hall = true },
            M = { name = "Mail Room", style = "records" },
            A = { name = "Map Room", style = "maps" },
            g = { name = "Stacks", style = "stacks", hall = true },
            B = { name = "Rare Books", style = "records" },
            C = { name = "Catalogue", style = "records" },
            D = { name = "Director's Office", style = "office" },
            K = { name = "Conservation Lab", style = "lab" },
            N = { name = "Study Carrels", style = "carrels" },
            J = { name = "Microfilm", style = "records" },
        },
        stairs = {
            { floor = 1, x = 2, z = 5, dir = "E", len = 2 }, -- service corridor up to the west hall
            { floor = 1, x = 11, z = 8, dir = "W", len = 2 }, -- loading bay up to the east hall
            { floor = 2, x = 7, z = 8, dir = "W", len = 2 }, -- lobby up to the carrels
            { floor = 2, x = 11, z = 4, dir = "W", len = 2 }, -- east stairs up to the stacks
        },
    },
} :: { [string]: Plan }

function MapPlan.Key(f: number, x: number, z: number): string
    return ("%d:%d:%d"):format(f, x, z)
end

function MapPlan.Size(plan: Plan): (number, number, number)
    return #plan.floors[1][1], #plan.floors[1], #plan.floors
end

function MapPlan.Cell(plan: Plan, f: number, x: number, z: number): string
    local rows = plan.floors[f]
    local row = rows and rows[z]
    if not row or x < 1 or x > #row then
        return "."
    end
    return string.sub(row, x, x)
end

function MapPlan.IsWalkable(ch: string): boolean
    return ch ~= "." and ch ~= "^"
end

-- World position of a cell's centre on its floor surface. The grid is centred
-- on the origin and floor 1 stands at y = 0.
function MapPlan.Position(plan: Plan, f: number, x: number, z: number): (number, number, number)
    local gw, gd = MapPlan.Size(plan)
    return (x - 0.5 - gw / 2) * MapPlan.CELL,
        (f - 1) * MapPlan.FLOOR_HEIGHT,
        (z - 0.5 - gd / 2) * MapPlan.CELL
end

local function isOutdoor(plan: Plan, ch: string): boolean
    local region = plan.regions[ch]
    return region ~= nil and region.outdoor == true
end

-- A ^ cell is part of whatever space it opens down into: the first cell under
-- it that is not itself open. Nil if the hole falls through the bottom of the
-- building or onto ground nobody stands on. BuildMaps paints the walls around
-- a stairwell in the colours of the room it looks down into.
function MapPlan.OpensInto(plan: Plan, f: number, x: number, z: number): string?
    local g = f - 1
    while g >= 1 do
        local ch = MapPlan.Cell(plan, g, x, z)
        if ch ~= "^" then
            return if MapPlan.IsWalkable(ch) then ch else nil
        end
        g -= 1
    end
    return nil
end

local function outdoorBelow(plan: Plan, f: number, x: number, z: number): boolean
    local ch = MapPlan.OpensInto(plan, f, x, z)
    return ch ~= nil and isOutdoor(plan, ch)
end

-- What stands between two neighbouring cells on one floor
local function kindBetween(
    plan: Plan,
    f: number,
    ax: number,
    az: number,
    bx: number,
    bz: number
): string
    local a, b = MapPlan.Cell(plan, f, ax, az), MapPlan.Cell(plan, f, bx, bz)
    local wa, wb = MapPlan.IsWalkable(a), MapPlan.IsWalkable(b)
    if wa and wb then
        if a == b or (isOutdoor(plan, a) and isOutdoor(plan, b)) then
            return "none"
        end
        return "wall"
    elseif wa or wb then
        local here, other = if wa then a else b, if wa then b else a
        if other == "^" then
            return "railing"
        end
        return if isOutdoor(plan, here) then "railing" else "exterior"
    elseif a == b then
        return "none" -- two ^ cells, or two empty ones
    end
    local hx, hz = if a == "^" then ax else bx, if a == "^" then az else bz
    return if outdoorBelow(plan, f, hx, hz) then "railing" else "exterior"
end

-- Edges are addressed by the grid line they lie on. axis "x": the line
-- x = line, between cells (line, index) and (line + 1, index). axis "z": the
-- line z = line, between cells (index, line) and (index, line + 1).
function MapPlan.EdgeId(f: number, axis: string, line: number, index: number): string
    return ("%d:%s:%d:%d"):format(f, axis, line, index)
end

local SIDE_EDGE = {
    E = function(x, z)
        return "x", x, z
    end,
    W = function(x, z)
        return "x", x - 1, z
    end,
    S = function(x, z)
        return "z", z, x
    end,
    N = function(x, z)
        return "z", z - 1, x
    end,
}

export type Edge = {
    floor: number,
    axis: string,
    line: number,
    index: number,
    kind: string, -- wall | exterior | railing | door | open
    a: string, -- the cell on the low side of the line
    b: string, -- the cell on the high side
    lockdown: boolean?,
}

export type ResolvedStair = {
    floor: number,
    dir: string,
    dx: number,
    dz: number,
    len: number,
    cells: { { x: number, z: number } },
    approach: { x: number, z: number },
    arrival: { x: number, z: number },
}

export type Analysis = {
    edges: { Edge },
    byId: { [string]: Edge },
    stairs: { ResolvedStair },
    ramp: { [string]: boolean }, -- cells a staircase stands on
    approach: { [string]: boolean },
    roof: { [string]: boolean }, -- cells with a roof over their floor
    problems: { string },
}

function MapPlan.EdgeKind(analysis: Analysis, f: number, x: number, z: number, side: string): string
    local axis, line, index = SIDE_EDGE[side](x, z)
    local edge = analysis.byId[MapPlan.EdgeId(f, axis, line, index)]
    return if edge then edge.kind else "none"
end

function MapPlan.SideEdgeId(f: number, x: number, z: number, side: string): string
    local axis, line, index = SIDE_EDGE[side](x, z)
    return MapPlan.EdgeId(f, axis, line, index)
end

-- The two cells either side of an edge
function MapPlan.EdgeCells(edge: Edge): (number, number, number, number)
    if edge.axis == "x" then
        return edge.line, edge.index, edge.line + 1, edge.index
    end
    return edge.index, edge.line, edge.index, edge.line + 1
end

local DOOR_EVERY = 5 -- cells of straight wall per doorway

function MapPlan.Analyse(plan: Plan): Analysis
    local gw, gd, floors = MapPlan.Size(plan)
    local problems = {}
    for f, rows in plan.floors do
        if #rows ~= gd then
            table.insert(problems, ("floor %d has %d rows, not %d"):format(f, #rows, gd))
        end
        for z, row in rows do
            if #row ~= gw then
                table.insert(
                    problems,
                    ("floor %d row %d is %d wide, not %d"):format(f, z, #row, gw)
                )
            end
            for x = 1, #row do
                local ch = string.sub(row, x, x)
                if MapPlan.IsWalkable(ch) and not plan.regions[ch] then
                    table.insert(problems, ("floor %d: no region named %q"):format(f, ch))
                end
            end
        end
    end

    -- Staircases
    local stairs: { ResolvedStair } = {}
    local ramp, approach, arrivalEdges = {}, {}, {}
    for i, s in plan.stairs do
        local d = MapPlan.DIRS[s.dir]
        if not d then
            table.insert(problems, ("stair %d: bad direction %s"):format(i, tostring(s.dir)))
            continue
        end
        local dx, dz = d[1], d[2]
        local region = MapPlan.Cell(plan, s.floor, s.x - dx, s.z - dz)
        local cells = {}
        for step = 0, s.len - 1 do
            local x, z = s.x + dx * step, s.z + dz * step
            table.insert(cells, { x = x, z = z })
            ramp[MapPlan.Key(s.floor, x, z)] = true
            if MapPlan.Cell(plan, s.floor, x, z) ~= region then
                table.insert(
                    problems,
                    ("stair %d: cell %d,%d is not in the approach's region"):format(i, x, z)
                )
            end
            if MapPlan.Cell(plan, s.floor + 1, x, z) ~= "^" then
                table.insert(
                    problems,
                    ("stair %d: floor %d is not open above %d,%d"):format(i, s.floor + 1, x, z)
                )
            end
        end
        local top = cells[#cells]
        local arrival = { x = top.x + dx, z = top.z + dz }
        if not MapPlan.IsWalkable(region) then
            table.insert(problems, ("stair %d: nowhere to step on at the bottom"):format(i))
        end
        if
            s.floor + 1 > floors
            or not MapPlan.IsWalkable(MapPlan.Cell(plan, s.floor + 1, arrival.x, arrival.z))
        then
            table.insert(problems, ("stair %d: nowhere to step off at the top"):format(i))
        end
        approach[MapPlan.Key(s.floor, s.x - dx, s.z - dz)] = true
        local axis, line, index = SIDE_EDGE[s.dir](top.x, top.z)
        arrivalEdges[MapPlan.EdgeId(s.floor + 1, axis, line, index)] = true
        table.insert(stairs, {
            floor = s.floor,
            dir = s.dir,
            dx = dx,
            dz = dz,
            len = s.len,
            cells = cells,
            approach = { x = s.x - dx, z = s.z - dz },
            arrival = arrival,
        })
    end

    -- Every edge that has something on it
    local edges: { Edge } = {}
    local byId: { [string]: Edge } = {}
    local function add(f, axis, line, index, ax, az, bx, bz)
        local id = MapPlan.EdgeId(f, axis, line, index)
        local kind = if arrivalEdges[id] then "open" else kindBetween(plan, f, ax, az, bx, bz)
        if kind == "none" then
            return
        end
        local edge = {
            floor = f,
            axis = axis,
            line = line,
            index = index,
            kind = kind,
            a = MapPlan.Cell(plan, f, ax, az),
            b = MapPlan.Cell(plan, f, bx, bz),
        }
        table.insert(edges, edge)
        byId[id] = edge
    end
    for f = 1, floors do
        for line = 0, gw do
            for z = 1, gd do
                add(f, "x", line, z, line, z, line + 1, z)
            end
        end
        for line = 0, gd do
            for x = 1, gw do
                add(f, "z", line, x, x, line, x, line + 1)
            end
        end
    end

    -- Doorways: split walls into straight stretches between the same two
    -- regions and open one doorway per DOOR_EVERY cells, never beside a stair
    local run: { Edge } = {}
    local function closeRun()
        local n = #run
        if n == 0 then
            return
        end
        local valid = {}
        for i, edge in run do
            local ax, az, bx, bz = MapPlan.EdgeCells(edge)
            valid[i] = not ramp[MapPlan.Key(edge.floor, ax, az)]
                and not ramp[MapPlan.Key(edge.floor, bx, bz)]
        end
        local doors = math.max(1, math.floor(n / DOOR_EVERY + 0.5))
        for d = 1, doors do
            local target = math.floor((d - 0.5) * n / doors) + 1
            local best, bestGap = nil, math.huge
            for i = 1, n do
                if valid[i] and run[i].kind == "wall" and math.abs(i - target) < bestGap then
                    best, bestGap = i, math.abs(i - target)
                end
            end
            if best then
                run[best].kind = "door"
            end
        end
        run = {}
    end
    local last: Edge? = nil
    for _, edge in edges do
        local continues = last ~= nil
            and edge.kind == "wall"
            and last.kind == "wall"
            and last.floor == edge.floor
            and last.axis == edge.axis
            and last.line == edge.line
            and last.index + 1 == edge.index
            and ((last.a == edge.a and last.b == edge.b) or (last.a == edge.b and last.b == edge.a))
        if not continues then
            closeRun()
        end
        if edge.kind == "wall" then
            table.insert(run, edge)
            last = edge
        else
            last = nil
        end
    end
    closeRun()

    -- Roofs over the top of each floor wherever nothing stands above
    local roof = {}
    for f = 1, floors do
        for z = 1, gd do
            for x = 1, gw do
                local ch = MapPlan.Cell(plan, f, x, z)
                if ch == "." or MapPlan.Cell(plan, f + 1, x, z) ~= "." then
                    continue
                end
                local outdoor = if ch == "^"
                    then outdoorBelow(plan, f, x, z)
                    else isOutdoor(plan, ch)
                if not outdoor then
                    roof[MapPlan.Key(f, x, z)] = true
                end
            end
        end
    end

    local analysis: Analysis = {
        edges = edges,
        byId = byId,
        stairs = stairs,
        ramp = ramp,
        approach = approach,
        roof = roof,
        problems = problems,
    }

    -- Lockdown shuts one doorway into each room, keeping a closure only while
    -- every cell stays reachable, so it reroutes the chase and seals no one in
    local function room(f: number, ch: string): string?
        local region = plan.regions[ch]
        return if region and not region.hall and not region.outdoor then f .. ch else nil
    end
    local shut: { [string]: boolean } = {}
    for _, edge in edges do
        if edge.kind ~= "door" then
            continue
        end
        local ra, rb = room(edge.floor, edge.a), room(edge.floor, edge.b)
        if not (ra or rb) or (ra and shut[ra]) or (rb and shut[rb]) then
            continue
        end
        edge.lockdown = true
        local reached, total = MapPlan.Reachable(plan, analysis, true)
        if reached == total then
            shut[ra or ""] = true
            shut[rb or ""] = true
        else
            edge.lockdown = nil
        end
    end
    return analysis
end

-- Walkable cells a player can stand on: every walkable cell except the ones a
-- staircase occupies
function MapPlan.Standable(plan: Plan, analysis: Analysis): { { f: number, x: number, z: number } }
    local gw, gd, floors = MapPlan.Size(plan)
    local out = {}
    for f = 1, floors do
        for z = 1, gd do
            for x = 1, gw do
                if
                    MapPlan.IsWalkable(MapPlan.Cell(plan, f, x, z))
                    and not analysis.ramp[MapPlan.Key(f, x, z)]
                then
                    table.insert(out, { f = f, x = x, z = z })
                end
            end
        end
    end
    return out
end

-- Where a walk can step from a cell: through open floor and doorways, and up
-- or down a staircase
local function stairLinks(analysis: Analysis): { [string]: { string } }
    local links: { [string]: { string } } = {}
    for _, s in analysis.stairs do
        local a = MapPlan.Key(s.floor, s.approach.x, s.approach.z)
        local b = MapPlan.Key(s.floor + 1, s.arrival.x, s.arrival.z)
        links[a] = links[a] or {}
        links[b] = links[b] or {}
        table.insert(links[a], b)
        table.insert(links[b], a)
    end
    return links
end

local function keyToCell(key: string)
    local f, x, z = string.match(key, "(%d+):(%d+):(%d+)")
    return { f = tonumber(f) :: number, x = tonumber(x) :: number, z = tonumber(z) :: number }
end

-- Breadth-first walk from `startKey`, returning which cells were reached and
-- the cell each was reached from
local function walk(
    plan: Plan,
    analysis: Analysis,
    startKey: string,
    lockdown: boolean?
): ({ [string]: boolean }, { [string]: string })
    local standable = {}
    for _, c in MapPlan.Standable(plan, analysis) do
        standable[MapPlan.Key(c.f, c.x, c.z)] = true
    end
    local links = stairLinks(analysis)
    local seen, from = { [startKey] = true }, {}
    if not standable[startKey] then
        return {}, {}
    end
    local queue, head = { keyToCell(startKey) }, 1
    while head <= #queue do
        local c = queue[head]
        head += 1
        local here = MapPlan.Key(c.f, c.x, c.z)
        for side, d in MapPlan.DIRS do
            local key = MapPlan.Key(c.f, c.x + d[1], c.z + d[2])
            local edge = analysis.byId[MapPlan.SideEdgeId(c.f, c.x, c.z, side)]
            local passable = edge == nil
                or (edge.kind == "door" and not (lockdown and edge.lockdown))
            if standable[key] and not seen[key] and passable then
                seen[key], from[key] = true, here
                table.insert(queue, { f = c.f, x = c.x + d[1], z = c.z + d[2] })
            end
        end
        for _, key in links[here] or {} do
            if standable[key] and not seen[key] then
                seen[key], from[key] = true, here
                table.insert(queue, keyToCell(key))
            end
        end
    end
    return seen, from
end

-- How many standable cells can be reached from the first one, with Lockdown
-- doors shut when `lockdown` is set. Returns reached, total and the keys of
-- any cell left out.
function MapPlan.Reachable(
    plan: Plan,
    analysis: Analysis,
    lockdown: boolean?
): (number, number, { string })
    local cells = MapPlan.Standable(plan, analysis)
    if #cells == 0 then
        return 0, 0, {}
    end
    local seen = walk(plan, analysis, MapPlan.Key(cells[1].f, cells[1].x, cells[1].z), lockdown)
    local reached, missing = 0, {}
    for _, c in cells do
        local key = MapPlan.Key(c.f, c.x, c.z)
        if seen[key] then
            reached += 1
        else
            table.insert(missing, key)
        end
    end
    return reached, #cells, missing
end

-- The cells to walk through to get from one cell to another, the first step
-- first and the goal last. NPCs walk it one short leg at a time, which keeps
-- each path request cheap and sends them through known doorways and stairs.
function MapPlan.Route(plan: Plan, analysis: Analysis, from, to): { any }?
    local startKey, goalKey = MapPlan.Key(from.f, from.x, from.z), MapPlan.Key(to.f, to.x, to.z)
    if startKey == goalKey then
        return {}
    end
    local seen, cameFrom = walk(plan, analysis, startKey)
    if not seen[goalKey] then
        return nil
    end
    local route, key = {}, goalKey
    while key and key ~= startKey do
        table.insert(route, 1, keyToCell(key))
        key = cameFrom[key]
    end
    return route
end

-- The cell a world position stands in
function MapPlan.CellAt(plan: Plan, x: number, y: number, z: number): (number, number, number)
    local gw, gd = MapPlan.Size(plan)
    return math.floor(y / MapPlan.FLOOR_HEIGHT + 0.5) + 1,
        math.floor(x / MapPlan.CELL + gw / 2) + 1,
        math.floor(z / MapPlan.CELL + gd / 2) + 1
end

-- Spawn and coin cells spread through the whole building: each pick is the
-- standable cell farthest from every earlier pick. Height counts double, so
-- the picks reach every floor.
function MapPlan.Points(plan: Plan, analysis: Analysis): { spawns: { any }, coins: { any } }
    local cells = MapPlan.Standable(plan, analysis)
    local function distance(a, b): number
        local ax, ay, az = MapPlan.Position(plan, a.f, a.x, a.z)
        local bx, by, bz = MapPlan.Position(plan, b.f, b.x, b.z)
        return math.sqrt((ax - bx) ^ 2 + ((ay - by) * 2) ^ 2 + (az - bz) ^ 2)
    end
    local function spread(count: number, pool, avoid)
        local chosen = {}
        local gap = {}
        for i, c in pool do
            gap[i] = math.huge
            for _, other in avoid do
                gap[i] = math.min(gap[i], distance(c, other))
            end
        end
        local taken = {}
        for _ = 1, math.min(count, #pool) do
            local best, bestGap = nil, -1
            for i in pool do
                if not taken[i] and gap[i] > bestGap then
                    best, bestGap = i, gap[i]
                end
            end
            if best == nil then
                break
            end
            taken[best] = true
            local pick = pool[best]
            table.insert(chosen, pick)
            for i, c in pool do
                gap[i] = math.min(gap[i], distance(c, pick))
            end
        end
        return chosen
    end

    -- Start the spawns from the corner cell farthest from the middle
    local fx, fy, fz = 0, 0, 0
    for _, c in cells do
        local x, y, z = MapPlan.Position(plan, c.f, c.x, c.z)
        fx, fy, fz = fx + x, fy + y, fz + z
    end
    local n = math.max(#cells, 1)
    local mid = { fx / n, fy / n, fz / n }
    local farthest, far = cells[1], -1
    for _, c in cells do
        local x, y, z = MapPlan.Position(plan, c.f, c.x, c.z)
        local d = (x - mid[1]) ^ 2 + ((y - mid[2]) * 2) ^ 2 + (z - mid[3]) ^ 2
        if d > far then
            farthest, far = c, d
        end
    end

    local spawns = { farthest }
    for _, c in spread(MapPlan.SPAWNS - 1, cells, spawns) do
        table.insert(spawns, c)
    end
    local used = {}
    for _, c in spawns do
        used[MapPlan.Key(c.f, c.x, c.z)] = true
    end
    local rest = {}
    for _, c in cells do
        if not used[MapPlan.Key(c.f, c.x, c.z)] then
            table.insert(rest, c)
        end
    end
    return { spawns = spawns, coins = spread(MapPlan.COINS, rest, spawns) }
end

return MapPlan
