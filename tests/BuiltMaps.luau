-- Builds every map with the real BuildMaps under Lune's Roblox library and
-- looks at the geometry the way a player does. The plan tests in init.luau
-- can only say what the builder was told; these say what it built. Each
-- check here caught a defect that shipped: raw brick along the storey line
-- over every stairwell, bare wall stubs at corridor corners, and wall tops
-- lying in the plane of the floor above so brick flickered through it.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local MapPlan = require("../src/shared/MapPlan")

-- BuildMaps only ever draws NextNumber and NextInteger from its Random
local Rng = {}
Rng.__index = Rng
function Rng.new(seed: number)
    return setmetatable({ s = seed % 2147483647 + 1 }, Rng)
end
function Rng:NextNumber(a: number?, b: number?): number
    self.s = (self.s * 48271) % 2147483647
    local u = self.s / 2147483647
    return if a == nil then u else a + ((b :: number) - a) * u
end
function Rng:NextInteger(a: number, b: number): number
    return math.floor(self:NextNumber(a, b + 1))
end

-- The builder requires its neighbours by Instance and reads game.PlaceVersion,
-- so it runs in a small environment that resolves both against the repo
local function buildAll()
    local Instance = roblox.Instance
    local dataModel = Instance.new("DataModel")
    local game = setmetatable({
        PlaceVersion = 0,
        GetService = function(_, name)
            return dataModel:GetService(name)
        end,
    }, { __index = dataModel })
    local root = process.cwd
    local loaded = {}
    local function load(path: string)
        if loaded[path] then
            return loaded[path]
        end
        local env = {
            game = game,
            Instance = Instance,
            Vector3 = roblox.Vector3,
            CFrame = roblox.CFrame,
            Color3 = roblox.Color3,
            Enum = roblox.Enum,
            Random = Rng,
            require = function(target)
                return load(("%s/src/shared/%s.luau"):format(root, target.Name))
            end,
        }
        for name, value in
            {
                table = table,
                math = math,
                string = string,
                pcall = pcall,
                ipairs = ipairs,
                pairs = pairs,
                next = next,
                select = select,
                tostring = tostring,
                tonumber = tonumber,
                type = type,
                typeof = typeof,
                setmetatable = setmetatable,
                getmetatable = getmetatable,
                assert = assert,
                error = error,
                print = print,
                warn = warn,
                unpack = unpack,
                rawget = rawget,
                rawset = rawset,
            } :: { [string]: any }
        do
            env[name] = value
        end
        local chunk = luau.load(fs.readFile(path), { debugName = path, environment = env })
        loaded[path] = chunk()
        return loaded[path]
    end
    local shared = Instance.new("Folder")
    shared.Name = "Shared"
    shared.Parent = dataModel:GetService("ReplicatedStorage")
    for _, name in { "MapPlan", "Shuffle" } do
        local module = Instance.new("ModuleScript")
        module.Name = name
        module.Parent = shared
    end
    local BuildMaps = load(root .. "/src/serverstorage/Build/BuildMaps.luau")
    return BuildMaps({ force = true })
end

type Box = {
    name: string,
    x0: number,
    x1: number,
    y0: number,
    y1: number,
    z0: number,
    z1: number,
    hidden: boolean,
}

local function boxes(model): { Box }
    local out = {}
    for _, d in model:GetDescendants() do
        if not d:IsA("BasePart") then
            continue
        end
        local p = d.CFrame.Position
        -- World-axis extents: a bin body is a cylinder stood on end by a
        -- quarter turn, so its height runs along the part's X axis
        local cf, size = d.CFrame, d.Size
        local r, uv, l = cf.RightVector, cf.UpVector, cf.LookVector
        local s = roblox.Vector3.new(
            math.abs(r.X) * size.X + math.abs(uv.X) * size.Y + math.abs(l.X) * size.Z,
            math.abs(r.Y) * size.X + math.abs(uv.Y) * size.Y + math.abs(l.Y) * size.Z,
            math.abs(r.Z) * size.X + math.abs(uv.Z) * size.Y + math.abs(l.Z) * size.Z
        )
        table.insert(out, {
            name = d.Name,
            x0 = p.X - s.X / 2,
            x1 = p.X + s.X / 2,
            y0 = p.Y - s.Y / 2,
            y1 = p.Y + s.Y / 2,
            z0 = p.Z - s.Z / 2,
            z1 = p.Z + s.Z / 2,
            hidden = d.Transparency >= 1,
        })
    end
    return out
end

local function lineAt(line: number, cells: number): number
    return (line - cells / 2) * MapPlan.CELL
end

-- The first opaque box along an axis-aligned ray, and how far away it is
local function cast(all: { Box }, px, py, pz, axis: string, sign: number, maxd: number)
    local best, bestd = nil, maxd
    for _, b in all do
        if b.hidden or py <= b.y0 or py >= b.y1 then
            continue
        end
        local d
        if axis == "x" then
            if pz <= b.z0 or pz >= b.z1 then
                continue
            end
            d = if sign > 0 then b.x0 - px else px - b.x1
            if px > b.x0 and px < b.x1 then
                d = 0
            end
        else
            if px <= b.x0 or px >= b.x1 then
                continue
            end
            d = if sign > 0 then b.z0 - pz else pz - b.z1
            if pz > b.z0 and pz < b.z1 then
                d = 0
            end
        end
        if d >= 0 and d < bestd then
            best, bestd = b, d
        end
    end
    return best, bestd
end

-- The first opaque box straight up from a point, and how far away it is
local function castUp(all: { Box }, px, py, pz, maxd: number)
    local best, bestd = nil, maxd
    for _, b in all do
        if b.hidden or px <= b.x0 or px >= b.x1 or pz <= b.z0 or pz >= b.z1 then
            continue
        end
        local d = b.y0 - py
        if d >= 0 and d < bestd then
            best, bestd = b, d
        end
    end
    return best, bestd
end

return function(test: (string, () -> ()) -> ())
    local folder = buildAll()
    for _, model in folder:GetChildren() do
        local name = model.Name
        local plan = MapPlan.MAPS[name]
        local gw, gd, floors = MapPlan.Size(plan)
        local analysis = MapPlan.Analyse(plan)
        local all = boxes(model)
        local CELL, H = MapPlan.CELL, MapPlan.FLOOR_HEIGHT

        test(name .. " every indoor wall face is skinned", function()
            local skins = {}
            for _, b in all do
                if b.name == "WallSkin" then
                    table.insert(skins, b)
                end
            end
            for _, e in analysis.edges do
                if e.kind ~= "exterior" and e.kind ~= "wall" and e.kind ~= "door" then
                    continue
                end
                local ax, az, bx, bz = MapPlan.EdgeCells(e)
                local base = (e.floor - 1) * H
                local cx, cz
                if e.axis == "x" then
                    cx, cz = lineAt(e.line, gw), lineAt(e.index - 0.5, gd)
                else
                    cx, cz = lineAt(e.index - 0.5, gw), lineAt(e.line, gd)
                end
                for _, side in
                    {
                        { ch = e.a, face = -1, x = ax, z = az },
                        { ch = e.b, face = 1, x = bx, z = bz },
                    }
                do
                    local ch = if side.ch == "^"
                        then MapPlan.OpensInto(plan, e.floor, side.x, side.z)
                        else side.ch
                    local region = ch and plan.regions[ch]
                    if not region or region.outdoor then
                        continue
                    end
                    local found = false
                    for _, sk in skins do
                        local mx, my, mz =
                            (sk.x0 + sk.x1) / 2, (sk.y0 + sk.y1) / 2, (sk.z0 + sk.z1) / 2
                        local along = if e.axis == "x" then math.abs(mz - cz) else math.abs(mx - cx)
                        local across = if e.axis == "x"
                            then (mx - cx) * side.face
                            else (mz - cz) * side.face
                        if
                            math.abs(my - (base + H / 2)) < 3
                            and along < CELL / 2
                            and across > 0
                            and across < 2
                        then
                            found = true
                            break
                        end
                    end
                    assert(
                        found,
                        ("floor %d %s line %d cell %d,%d: %s faces bare wall"):format(
                            e.floor,
                            e.axis,
                            e.line,
                            side.x,
                            side.z,
                            region.name
                        )
                    )
                end
            end
        end)

        test(name .. " no wall end lies flush with a slab face", function()
            for _, w in all do
                if w.name ~= "Wall" and w.name ~= "Shell" and w.name ~= "Lintel" then
                    continue
                end
                for _, f in all do
                    if f.name ~= "Floor" and f.name ~= "Roof" then
                        continue
                    end
                    local flush = math.abs(w.y1 - f.y1) < 1e-3
                        or math.abs(w.y0 - f.y0) < 1e-3
                        or math.abs(w.y1 - f.y0) < 1e-3
                        or math.abs(w.y0 - f.y1) < 1e-3
                    if not flush then
                        continue
                    end
                    local ox = math.min(w.x1, f.x1) - math.max(w.x0, f.x0)
                    local oz = math.min(w.z1, f.z1) - math.max(w.z0, f.z0)
                    assert(
                        ox <= 0.01 or oz <= 0.01,
                        ("%s at x %.0f z %.0f shares a face with a slab at y %.1f"):format(
                            w.name,
                            (w.x0 + w.x1) / 2,
                            (w.z0 + w.z1) / 2,
                            w.y1
                        )
                    )
                end
            end
        end)

        -- A stairwell or a double-height hall is part of the room it opens
        -- into, and that room looks up through it: without a ceiling panel
        -- over the ^ cells it sees the raw underside of the slab or roof
        -- above, a dark wood patch over every stair and a slate cave over
        -- the Grand Hall. Only themed ceilings are checked; the Pier has none.
        local ceilings = 0
        for _, b in all do
            if b.name == "Ceiling" then
                ceilings += 1
            end
        end
        if ceilings > 0 then
            test(name .. " every indoor cell looks up at a ceiling", function()
                for f = 1, floors do
                    local base = (f - 1) * H
                    for z = 1, gd do
                        for x = 1, gw do
                            local ch = MapPlan.Cell(plan, f, x, z)
                            local space = if ch == "^" then MapPlan.OpensInto(plan, f, x, z) else ch
                            if
                                not space
                                or not MapPlan.IsWalkable(space)
                                or plan.regions[space].outdoor
                            then
                                continue
                            end
                            local cx = (lineAt(x - 1, gw) + lineAt(x, gw)) / 2
                            local cz = (lineAt(z - 1, gd) + lineAt(z, gd)) / 2
                            -- Off the centre, where a lamp cord hangs, and off
                            -- the grid, so no ray grazes a panel's edge
                            for _, off in { { -6, -6 }, { 6, -6 }, { -6, 6 }, { 6, 6 } } do
                                local hit =
                                    castUp(all, cx + off[1], base + H / 2, cz + off[2], H * floors)
                                assert(
                                    hit and hit.name == "Ceiling",
                                    ("floor %d %s at %d,%d (%s) looks up at %s"):format(
                                        f,
                                        plan.regions[space].name,
                                        x,
                                        z,
                                        ch,
                                        hit and hit.name or "the sky"
                                    )
                                )
                            end
                        end
                    end
                end
            end)
        end

        -- Decoration placed by rule: every bin stands on a floor slab inside a
        -- room and touches no wall, step or door; every picture hangs on a wall
        -- skin's room face, clear of windows, doorways and other pictures.
        test(name .. " bins stand on the floor, in a room, clear of every wall", function()
            local bins, solids, floors = {}, {}, {}
            for _, b in all do
                if b.name == "Bin" then
                    table.insert(bins, b)
                elseif b.name == "Floor" then
                    table.insert(floors, b)
                elseif
                    b.name == "Wall"
                    or b.name == "Shell"
                    or b.name == "Step"
                    or b.name == "Door"
                    or b.name == "DoorFrame"
                    or b.name == "Lintel"
                    or b.name == "Railing"
                    or b.name == "Banister"
                    or b.name == "WallSkin"
                then
                    table.insert(solids, b)
                end
            end
            assert(#bins > 0, "no bins were placed")
            local function overlaps(a, b)
                return a.x0 < b.x1
                    and a.x1 > b.x0
                    and a.y0 < b.y1
                    and a.y1 > b.y0
                    and a.z0 < b.z1
                    and a.z1 > b.z0
            end
            for _, bin in bins do
                local cx, cz = (bin.x0 + bin.x1) / 2, (bin.z0 + bin.z1) / 2
                local onFloor = false
                for _, f in floors do
                    if
                        cx > f.x0
                        and cx < f.x1
                        and cz > f.z0
                        and cz < f.z1
                        and math.abs(bin.y0 - f.y1) < 0.05
                    then
                        onFloor = true
                    end
                end
                assert(
                    onFloor,
                    ("bin at %.0f,%.1f,%.0f does not stand on a floor"):format(cx, bin.y0, cz)
                )
                for _, s in solids do
                    assert(
                        not overlaps(bin, s),
                        ("bin at %.0f,%.0f runs into a %s"):format(cx, cz, s.name)
                    )
                end
                local x = math.floor(cx / CELL + gw / 2) + 1
                local z = math.floor(cz / CELL + gd / 2) + 1
                local f = math.floor(bin.y0 / H + 0.5) + 1
                local ch = MapPlan.Cell(plan, f, x, z)
                assert(MapPlan.IsWalkable(ch), ("bin at %.0f,%.0f is not in a room"):format(cx, cz))
            end
        end)

        test(
            name .. " pictures hang on a wall face, clear of windows, doors and each other",
            function()
                local frames, skins, blockers = {}, {}, {}
                for _, b in all do
                    if b.name == "PaintingFrame" then
                        table.insert(frames, b)
                    elseif b.name == "WallSkin" then
                        table.insert(skins, b)
                    elseif
                        b.name == "Window"
                        or b.name == "WindowFrame"
                        or b.name == "DoorFrame"
                        or b.name == "Lintel"
                        or b.name == "Door"
                        or b.name == "Lamp"
                        or b.name == "LampShade"
                    then
                        table.insert(blockers, b)
                    end
                end
                assert(#frames > 0, "no pictures were hung")
                local function overlaps(a, b)
                    return a.x0 < b.x1
                        and a.x1 > b.x0
                        and a.y0 < b.y1
                        and a.y1 > b.y0
                        and a.z0 < b.z1
                        and a.z1 > b.z0
                end
                for i, fr in frames do
                    local cx, cz = (fr.x0 + fr.x1) / 2, (fr.z0 + fr.z1) / 2
                    -- Its back is on a skin: the frame and a skin overlap by a hair,
                    -- never by more than the deliberate embed
                    local seated = false
                    for _, sk in skins do
                        if overlaps(fr, sk) then
                            local depth = math.min(
                                math.min(fr.x1, sk.x1) - math.max(fr.x0, sk.x0),
                                math.min(fr.z1, sk.z1) - math.max(fr.z0, sk.z0)
                            )
                            assert(
                                depth < 0.05,
                                ("picture at %.0f,%.0f is buried in a wall skin"):format(cx, cz)
                            )
                            seated = true
                        end
                    end
                    assert(seated, ("picture at %.0f,%.0f hangs on nothing"):format(cx, cz))
                    for _, b in blockers do
                        assert(
                            not overlaps(fr, b),
                            ("picture at %.0f,%.0f covers a %s"):format(cx, cz, b.name)
                        )
                    end
                    for j = i + 1, #frames do
                        assert(
                            not overlaps(fr, frames[j]),
                            ("two pictures overlap at %.0f,%.0f"):format(cx, cz)
                        )
                    end
                end
            end
        )

        test(
            name .. " runners, rugs and mats lie flat on the floor, clear of steps, walls and bins",
            function()
                local soft, hard, floors = {}, {}, {}
                for _, b in all do
                    if b.name == "Runner" or b.name == "Rug" or b.name == "Doormat" then
                        table.insert(soft, b)
                    elseif b.name == "Floor" then
                        table.insert(floors, b)
                    elseif
                        b.name == "Wall"
                        or b.name == "Shell"
                        or b.name == "Step"
                        or b.name == "Bin"
                        or b.name == "Door"
                    then
                        table.insert(hard, b)
                    end
                end
                local function overlaps(a, b)
                    return a.x0 < b.x1
                        and a.x1 > b.x0
                        and a.y0 < b.y1
                        and a.y1 > b.y0
                        and a.z0 < b.z1
                        and a.z1 > b.z0
                end
                local mats = 0
                for _, r in soft do
                    local cx, cz = (r.x0 + r.x1) / 2, (r.z0 + r.z1) / 2
                    if r.name == "Doormat" then
                        mats += 1
                    end
                    local onFloor = false
                    for _, f in floors do
                        if
                            cx > f.x0
                            and cx < f.x1
                            and cz > f.z0
                            and cz < f.z1
                            and math.abs(r.y0 - f.y1) < 0.05
                        then
                            onFloor = true
                        end
                    end
                    assert(onFloor, ("%s at %.0f,%.0f is not on a floor"):format(r.name, cx, cz))
                    for _, h in hard do
                        assert(
                            not overlaps(r, h),
                            ("%s at %.0f,%.0f runs into a %s"):format(r.name, cx, cz, h.name)
                        )
                    end
                end
                assert(mats > 0, "no doormats were laid")
            end
        )

        test(
            name .. " curtains and clocks hang on a wall face, clear of windows, pictures and doors",
            function()
                local hung, skins, blockers = {}, {}, {}
                for _, b in all do
                    if b.name == "Curtain" or b.name == "ClockRim" then
                        table.insert(hung, b)
                    elseif b.name == "WallSkin" then
                        table.insert(skins, b)
                    elseif
                        b.name == "Window"
                        or b.name == "WindowFrame"
                        or b.name == "PaintingFrame"
                        or b.name == "DoorFrame"
                        or b.name == "Lintel"
                        or b.name == "Lamp"
                        or b.name == "LampShade"
                    then
                        table.insert(blockers, b)
                    end
                end
                local function overlaps(a, b)
                    return a.x0 < b.x1
                        and a.x1 > b.x0
                        and a.y0 < b.y1
                        and a.y1 > b.y0
                        and a.z0 < b.z1
                        and a.z1 > b.z0
                end
                for _, h in hung do
                    local cx, cz = (h.x0 + h.x1) / 2, (h.z0 + h.z1) / 2
                    local seated = false
                    for _, sk in skins do
                        if overlaps(h, sk) then
                            local depth = math.min(
                                math.min(h.x1, sk.x1) - math.max(h.x0, sk.x0),
                                math.min(h.z1, sk.z1) - math.max(h.z0, sk.z0)
                            )
                            assert(
                                depth < 0.05,
                                ("%s at %.0f,%.0f is buried in a wall skin"):format(h.name, cx, cz)
                            )
                            seated = true
                        end
                    end
                    assert(seated, ("%s at %.0f,%.0f hangs on nothing"):format(h.name, cx, cz))
                    for _, b in blockers do
                        assert(
                            not overlaps(h, b),
                            ("%s at %.0f,%.0f covers a %s"):format(h.name, cx, cz, b.name)
                        )
                    end
                end
            end
        )

        test(name .. " no bare wall can be seen from any room", function()
            for f = 1, floors do
                local base = (f - 1) * H
                for z = 1, gd do
                    for x = 1, gw do
                        local ch = MapPlan.Cell(plan, f, x, z)
                        if not MapPlan.IsWalkable(ch) or plan.regions[ch].outdoor then
                            continue
                        end
                        local cx = (lineAt(x - 1, gw) + lineAt(x, gw)) / 2
                        local cz = (lineAt(z - 1, gd) + lineAt(z, gd)) / 2
                        -- Every stud of the storey, from inside the slab
                        -- below to inside the slab above, off the grid so
                        -- no ray grazes a part's edge
                        for h = -0.25, H - 0.25 do
                            for _, off in { -7, 0, 7 } do
                                for _, dir in { { "x", 1 }, { "x", -1 }, { "z", 1 }, { "z", -1 } } do
                                    local px, pz = cx, cz
                                    if dir[1] == "x" then
                                        pz += off
                                    else
                                        px += off
                                    end
                                    local hit =
                                        cast(all, px, base + h, pz, dir[1], dir[2], CELL * 6)
                                    assert(
                                        not hit or (hit.name ~= "Shell" and hit.name ~= "Wall"),
                                        ("floor %d %s at %d,%d sees bare %s looking %s%+d, %.1f up"):format(
                                            f,
                                            plan.regions[ch].name,
                                            x,
                                            z,
                                            hit and hit.name or "",
                                            dir[1],
                                            dir[2],
                                            h
                                        )
                                    )
                                end
                            end
                        end
                    end
                end
            end
        end)
    end
end
