--!strict
-- Particle looks for Effect items (worn as an aura at the feet) and knife
-- effects (Shop.EFFECTS, on the blade while it is drawn). Built-in particle
-- textures only. Nothing here glows: LightEmission is 0 so a cosmetic never
-- helps anyone see during Lights Out.
local SPARKLES = "rbxasset://textures/particles/sparkles_main.dds"
local FIRE = "rbxasset://textures/particles/fire_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"

export type Fx = {
    texture: string,
    colour: Color3,
    rate: number,
    lifetime: NumberRange,
    size: number,
    speed: NumberRange,
    spread: number?,
    accel: Vector3?,
    transparency: number?,
}

local CosmeticFx = {}

CosmeticFx.AURA = {
    matchstick = {
        texture = FIRE,
        colour = Color3.fromHex("f29a3b"),
        rate = 4,
        lifetime = NumberRange.new(0.4, 0.8),
        size = 0.35,
        speed = NumberRange.new(1, 2),
        accel = Vector3.new(0, 3, 0),
    },
    static = {
        texture = SPARKLES,
        colour = Color3.fromHex("37bcf0"),
        rate = 8,
        lifetime = NumberRange.new(0.15, 0.3),
        size = 0.4,
        speed = NumberRange.new(2, 4),
        spread = 180,
    },
    frostbite = {
        texture = SPARKLES,
        colour = Color3.fromHex("cfe8ff"),
        rate = 5,
        lifetime = NumberRange.new(1, 1.6),
        size = 0.3,
        speed = NumberRange.new(0.5, 1),
        accel = Vector3.new(0, -1, 0),
        spread = 180,
    },
    bellwether = {
        texture = SPARKLES,
        colour = Color3.fromHex("f2c14e"),
        rate = 3,
        lifetime = NumberRange.new(1.2, 1.8),
        size = 0.6,
        speed = NumberRange.new(0.5, 1),
        accel = Vector3.new(0, 1, 0),
        spread = 180,
    },
    -- Design Bible: frost prints that fade over four seconds
    thelongnightfx = {
        texture = SMOKE,
        colour = Color3.fromHex("bcd4ea"),
        rate = 2,
        lifetime = NumberRange.new(4, 4),
        size = 0.9,
        speed = NumberRange.new(0, 0),
        transparency = 0.6,
    },
    -- VIP exclusive: a steady rise of gold motes, denser than Bellwether so it
    -- reads as regalia. LightEmission stays 0 like every aura (no Lights Out edge).
    regalia = {
        texture = SPARKLES,
        colour = Color3.fromHex("f2c14e"),
        rate = 7,
        lifetime = NumberRange.new(1, 1.5),
        size = 0.5,
        speed = NumberRange.new(0.5, 1),
        accel = Vector3.new(0, 1.6, 0),
        spread = 180,
    },
} :: { [string]: Fx }

CosmeticFx.KNIFE = {
    ember = {
        texture = FIRE,
        colour = Color3.fromHex("f29a3b"),
        rate = 10,
        lifetime = NumberRange.new(0.2, 0.4),
        size = 0.2,
        speed = NumberRange.new(0.5, 1),
    },
    frost = {
        texture = SPARKLES,
        colour = Color3.fromHex("cfe8ff"),
        rate = 8,
        lifetime = NumberRange.new(0.4, 0.8),
        size = 0.2,
        speed = NumberRange.new(0.2, 0.5),
        spread = 180,
    },
    static = {
        texture = SPARKLES,
        colour = Color3.fromHex("37bcf0"),
        rate = 14,
        lifetime = NumberRange.new(0.1, 0.2),
        size = 0.25,
        speed = NumberRange.new(1, 2),
        spread = 180,
    },
    ash = {
        texture = SMOKE,
        colour = Color3.fromHex("6f7883"),
        rate = 6,
        lifetime = NumberRange.new(0.8, 1.2),
        size = 0.4,
        speed = NumberRange.new(0.3, 0.6),
        transparency = 0.5,
    },
    gold = {
        texture = SPARKLES,
        colour = Color3.fromHex("f2c14e"),
        rate = 8,
        lifetime = NumberRange.new(0.4, 0.7),
        size = 0.25,
        speed = NumberRange.new(0.3, 0.6),
        spread = 180,
    },
} :: { [string]: Fx }

function CosmeticFx.Emitter(fx: Fx): ParticleEmitter
    local e = Instance.new("ParticleEmitter")
    e.Name = "CosmeticFx"
    e.Texture = fx.texture
    e.Color = ColorSequence.new(fx.colour)
    e.Rate = fx.rate
    e.Lifetime = fx.lifetime
    e.Size = NumberSequence.new(fx.size, 0)
    e.Speed = fx.speed
    e.SpreadAngle = Vector2.new(fx.spread or 25, fx.spread or 25)
    e.Acceleration = fx.accel or Vector3.zero
    e.Transparency = NumberSequence.new(fx.transparency or 0.2, 1)
    e.LightEmission = 0
    e.LightInfluence = 1
    return e
end

return CosmeticFx
