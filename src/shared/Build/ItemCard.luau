--!strict
-- One item tile, used by the crate reel, direct-buy shelf, inventory and trade.
local Theme = require(script.Parent.Parent.Theme)
local Catalog = require(script.Parent.Parent.Catalog)
local Rarities = require(script.Parent.Parent.RarityTable)

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
    RARITY_COLOUR = RARITY_COLOUR,
}
