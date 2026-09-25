--!strict
-- One item tile, used by the crate reel, direct-buy shelf, inventory and trade.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Theme = require(script.Parent.Parent.Theme)
local Catalog = require(script.Parent.Parent.Catalog)
local Rarities = require(script.Parent.Parent.RarityTable)

-- Show the real item in a small 3D viewport for every knife, pistol and pet.
-- BuildAssets replicates one model per item into ReplicatedStorage.PreviewModels.
-- Whether an item HAS a mesh is decided from its catalogue kind, not from the
-- folder, so a card built before the folder replicates still gets a viewport
-- (filled once the model arrives) rather than being frozen on a diamond. Only
-- effects, which have no mesh, return false so the caller draws the diamond.
local function hasMesh(id: string): boolean
    local def = Catalog[id]
    return def ~= nil and (def.kind == "Knife" or def.kind == "Pistol" or def.kind == "Pet")
end

local function fill(vp: ViewportFrame, id: string)
    local folder = ReplicatedStorage:WaitForChild("PreviewModels", 15)
    local src = folder and folder:WaitForChild(id, 15)
    if not (src and src:IsA("Model") and vp.Parent) then
        return
    end
    local model = src:Clone()
    local ok, cf, size = pcall(function()
        return model:GetBoundingBox()
    end)
    if not ok then
        model:Destroy()
        return
    end
    local world = Instance.new("WorldModel")
    model.Parent = world
    world.Parent = vp
    local cam = Instance.new("Camera")
    local dist = math.max((size :: Vector3).Magnitude, 1) * 0.95 + 0.5
    local dir = Vector3.new(0.55, 0.4, 1).Unit
    cam.CFrame = CFrame.lookAt((cf :: CFrame).Position + dir * dist, (cf :: CFrame).Position)
    cam.FieldOfView = 40
    vp.CurrentCamera = cam
    cam.Parent = vp

    -- Chroma: the blade cycles through every hue. Runs only while the viewport
    -- is on screen and disconnects itself when it (or the model) goes away.
    if Catalog[id] and Catalog[id].chroma then
        local parts = {}
        for _, d in model:GetDescendants() do
            if d:IsA("BasePart") then
                table.insert(parts, d)
            end
        end
        if model:IsA("BasePart") then
            table.insert(parts, model)
        end
        local conn
        conn = RunService.RenderStepped:Connect(function()
            if not (vp.Parent and model.Parent) then
                conn:Disconnect()
                return
            end
            local colour = Color3.fromHSV((os.clock() * 0.25) % 1, 0.85, 1)
            for _, p in parts do
                p.Color = colour
            end
        end)
    end
end

local function mountPreview(parent: Instance, id: string): boolean
    if not hasMesh(id) then
        return false
    end
    local vp = Instance.new("ViewportFrame")
    vp.Name = "Preview"
    vp.AnchorPoint = Vector2.new(0.5, 0.5)
    vp.Position = UDim2.fromScale(0.5, 0.3)
    vp.Size = UDim2.fromScale(0.66, 0.46)
    vp.BackgroundTransparency = 1
    vp.Ambient = Color3.fromRGB(196, 198, 208)
    vp.LightColor = Color3.fromRGB(255, 250, 238)
    vp.LightDirection = Vector3.new(-0.4, -1, -0.5)
    vp.Parent = parent
    task.spawn(fill, vp, id)
    return true
end

local RARITY_COLOUR = {}
for _, r in Rarities do
    RARITY_COLOUR[r.name] = r.colour
end

local function label(
    name: string,
    parent: Instance,
    text: string,
    font: Font,
    maxSize: number,
    colour: Color3
)
    local l = Instance.new("TextLabel")
    l.Name = name
    l.Text = text
    l.FontFace = font
    l.TextColor3 = colour
    l.BackgroundTransparency = 1
    l.TextScaled = true
    local limit = Instance.new("UITextSizeConstraint")
    limit.MaxTextSize = maxSize
    limit.Parent = l
    l.Parent = parent
    return l
end

-- `button` adds a transparent full-size TextButton named Button on top
local function ItemCard(parent: Instance, id: string, size: UDim2?, button: boolean?): Frame
    local def = Catalog[id]
    local colour = def and RARITY_COLOUR[def.rarity] or Theme.DIM

    local f = Instance.new("Frame")
    f.Name = "Card"
    f.Size = size or UDim2.fromOffset(132, 150)
    f.BackgroundColor3 = Color3.fromHex("131820")
    f.BorderSizePixel = 0
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = f
    local stroke = Instance.new("UIStroke")
    stroke.Name = "Stroke"
    stroke.Color = colour
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Parent = f

    if not mountPreview(f, id) then
        -- No mesh for this item (an effect): the rarity diamond stands in
        local swatch = Instance.new("Frame")
        swatch.Name = "Swatch"
        swatch.AnchorPoint = Vector2.new(0.5, 0.5)
        swatch.Position = UDim2.fromScale(0.5, 0.3)
        swatch.Size = UDim2.fromScale(0.28, 0.28)
        swatch.SizeConstraint = Enum.SizeConstraint.RelativeYY
        swatch.Rotation = 45
        swatch.BackgroundColor3 = colour
        swatch.BorderSizePixel = 0
        swatch.Parent = f
    end

    local name = label("ItemName", f, def and def.name or "?", Theme.DISPLAY, 18, Theme.INK)
    name.Position = UDim2.fromScale(0.05, 0.54)
    name.Size = UDim2.fromScale(0.9, 0.18)

    local rarity =
        label("Rarity", f, def and string.upper(def.rarity) or "", Theme.MONO, 10, colour)
    rarity.Position = UDim2.fromScale(0.05, 0.74)
    rarity.Size = UDim2.fromScale(0.9, 0.11)

    if button then
        local b = Instance.new("TextButton")
        b.Name = "Button"
        b.Text = ""
        b.BackgroundTransparency = 1
        b.Size = UDim2.fromScale(1, 1)
        b.ZIndex = 2
        b.Parent = f
    end

    f.Parent = parent
    return f
end

return {
    new = ItemCard,
    -- Adds a 3D preview viewport to any card frame that has room for one,
    -- returning true for a knife, pistol or pet and false for an effect so the
    -- caller can leave its own swatch showing. Used by the inventory tiles,
    -- which are cloned from a template rather than built by `new`.
    mount = mountPreview,
    RARITY_COLOUR = RARITY_COLOUR,
}
