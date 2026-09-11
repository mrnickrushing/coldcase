--[[
  COLD CASE · generated models, rebuilt from their uploaded mesh ids.
  Studio keeps ServerStorage.Cosmetics, ServerStorage.Props and
  ReplicatedStorage.PetModels in the place file. A place built by Rojo has
  none of them, so on server start any missing folder is rebuilt from
  AssetManifest with AssetService:CreateMeshPartAsync. Runs before BuildMaps,
  which dresses the maps from ServerStorage.Props.
]]
local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Manifest = require(script.Parent.AssetManifest)

local TIMEOUT = 30 -- seconds; a mesh that never loads falls back like a missing one

local function vector(t: { number }): Vector3
    return Vector3.new(t[1], t[2], t[3])
end

local function meshPart(spec): MeshPart?
    local ok, part = pcall(AssetService.CreateMeshPartAsync, AssetService, spec.mesh)
    if not ok then
        warn("[ColdCase] mesh " .. spec.mesh .. ": " .. tostring(part))
        return nil
    end
    part.TextureID = spec.texture
    part.Size = vector(spec.size)
    part.Anchored = true
    return part
end

local function model(name: string, parts, solid: boolean): Model
    local m = Instance.new("Model")
    m.Name = name
    for _, spec in parts do
        local part = meshPart(spec)
        if part then
            part.CFrame = CFrame.new(vector(spec.offset))
                * CFrame.fromEulerAnglesXYZ(spec.rot[1], spec.rot[2], spec.rot[3])
            part.CanCollide = solid
            part.CanQuery = solid
            part.CanTouch = false
            part.CastShadow = solid
            if spec.light then
                local light = Instance.new("PointLight")
                light.Color = Color3.fromHex(spec.light.colour)
                light.Range = spec.light.range
                light.Brightness = spec.light.brightness
                light.Parent = part
            end
            part.Parent = m
        end
    end
    m.WorldPivot = CFrame.identity
    return m
end

-- Runs every job at once and waits for all of them, or TIMEOUT
local function runAll(jobs: { () -> () })
    local pending = #jobs
    if pending == 0 then
        return
    end
    local done = Instance.new("BindableEvent")
    for _, job in jobs do
        task.spawn(function()
            local ok, err = pcall(job)
            if not ok then
                warn("[ColdCase] asset build: " .. tostring(err))
            end
            pending -= 1
            if pending == 0 then
                done:Fire()
            end
        end)
    end
    if pending > 0 then
        task.delay(TIMEOUT, function()
            done:Fire()
        end)
        done.Event:Wait()
    end
    done:Destroy()
end

return function()
    local jobs = {}
    local ready: { { folder: Folder, parent: Instance } } = {}

    local function folder(name: string, parent: Instance): Folder?
        if parent:FindFirstChild(name) then
            return nil -- the place file already has them
        end
        local f = Instance.new("Folder")
        f.Name = name
        table.insert(ready, { folder = f, parent = parent })
        return f
    end

    local cosmetics = folder("Cosmetics", ServerStorage)
    if cosmetics then
        for id, spec in Manifest.weapons do
            table.insert(jobs, function()
                local handle = meshPart(spec)
                if not handle then
                    return
                end
                handle.Name = "Handle"
                handle.Anchored = false
                handle.CanCollide = false
                handle.CanQuery = false
                handle.CanTouch = false
                handle.Massless = true
                local tool = Instance.new("Tool")
                tool.Name = id
                tool.CanBeDropped = false
                tool.RequiresHandle = true
                handle.Parent = tool
                tool.Parent = cosmetics
            end)
        end
    end

    local props = folder("Props", ServerStorage)
    if props then
        for name, parts in Manifest.props do
            table.insert(jobs, function()
                model(name, parts, true).Parent = props
            end)
        end
    end

    local pets = folder("PetModels", ReplicatedStorage)
    if pets then
        for name, parts in Manifest.pets do
            table.insert(jobs, function()
                model(name, parts, false).Parent = pets
            end)
        end
    end

    runAll(jobs)
    -- Parented only once complete, so nothing reads a half-built folder
    for _, entry in ready do
        entry.folder.Parent = entry.parent
    end
end
