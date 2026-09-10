--[[
  COLD CASE · map blockout builder
  Bootstrap runs this automatically when ServerStorage.Maps is missing, so a
  fresh `rojo build` is playable. It can also be run from the command bar:
    require(game.ServerStorage.Build.BuildMaps)({ force = true })
  Generates all three maps as Models in ServerStorage.Maps with walls, floor,
  tagged SpawnPoints, CoinNodes and LockdownDoors. Grey boxes only.
  Coordinates match the Map Blockouts canvas and its OBJ exports.
]]
local MAPS = {
    BlackwoodManor = {
        floor = Color3.fromHex("2a2620"),
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
        floor = Color3.fromHex("1f2830"),
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
        floor = Color3.fromHex("26221c"),
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

local function part(name, parent, size, pos, colour)
    local p = Instance.new("Part")
    p.Name = name
    p.Size = size
    p.Position = pos
    p.Color = colour
    p.Anchored = true
    p.TopSurface = Enum.SurfaceType.Smooth
    p.BottomSurface = Enum.SurfaceType.Smooth
    p.Material = Enum.Material.SmoothPlastic
    p.Parent = parent
    return p
end

-- Blockout rect (x, y, w, h from the top-left of a 960×600 plan) to a centred
-- part position at height h/2
local function rectCentre(r, h)
    return Vector3.new(r[1] + r[3] / 2 - W / 2, h / 2, r[2] + r[4] / 2 - D / 2)
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

        local floor =
            part("Floor_Base", model, Vector3.new(W, 2, D), Vector3.new(0, -1, 0), def.floor)
        model.PrimaryPart = floor

        for i, r in def.walls do
            part(
                ("Wall_%02d"):format(i),
                model,
                Vector3.new(r[3], h, r[4]),
                rectCentre(r, h),
                Color3.fromHex("5b6774")
            )
        end

        for i, r in def.doors do
            local door = part(
                ("Door_%02d"):format(i),
                model,
                Vector3.new(r[3], h, r[4]),
                rectCentre(r, h),
                Color3.fromHex("8a5a3c")
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
