--!strict
-- COLD CASE · combat feedback. A red spray where a blow lands and a muzzle
-- flash when a gun fires, spawned server-side so every client sees them. Both
-- self-clean through Debris. The impact keeps LightEmission 0 and is lit by the
-- scene, so it shows in daylight but stays dark during Lights Out - it must
-- never light a kill for someone who otherwise could not see. The muzzle flash
-- is self-bright: a gun is already the loudest, most-revealing act in a round
-- (gun_fire carries 220 studs), so its flash giving the shooter away fits.
local Debris = game:GetService("Debris")
local Workspace = game:GetService("Workspace")

local CombatFx = {}

local IMPACT = "rbxasset://textures/particles/smoke_main.dds"
local FLASH = "rbxasset://textures/particles/fire_main.dds"

local function anchor(position: Vector3): Part
    local p = Instance.new("Part")
    p.Anchored = true
    p.CanCollide = false
    p.CanQuery = false
    p.CanTouch = false
    p.Massless = true
    p.Transparency = 1
    p.Size = Vector3.new(0.2, 0.2, 0.2)
    p.CFrame = CFrame.new(position)
    return p
end

-- A short crimson spray at the point a blow lands.
function CombatFx.Impact(position: Vector3)
    local p = anchor(position + Vector3.new(0, 2, 0))
    local e = Instance.new("ParticleEmitter")
    e.Texture = IMPACT
    e.Color = ColorSequence.new(Color3.fromRGB(150, 22, 22), Color3.fromRGB(88, 10, 10))
    e.Transparency = NumberSequence.new(0.1, 1)
    e.Size = NumberSequence.new(0.7, 0.15)
    e.Lifetime = NumberRange.new(0.3, 0.6)
    e.Speed = NumberRange.new(7, 13)
    e.SpreadAngle = Vector2.new(180, 180)
    e.Acceleration = Vector3.new(0, -34, 0)
    e.Rate = 0
    e.LightEmission = 0
    e.LightInfluence = 1
    e.Parent = p
    p.Parent = Workspace
    e:Emit(18)
    Debris:AddItem(p, 0.8)
end

-- A brief bright flash just ahead of the muzzle.
function CombatFx.Muzzle(origin: Vector3, direction: Vector3)
    if direction.Magnitude < 1e-3 then
        return
    end
    local p = anchor(origin + direction.Unit * 1.6)
    local e = Instance.new("ParticleEmitter")
    e.Texture = FLASH
    e.Color = ColorSequence.new(Color3.fromRGB(255, 232, 150), Color3.fromRGB(255, 158, 40))
    e.Transparency = NumberSequence.new(0, 1)
    e.Size = NumberSequence.new(2.4, 0.2)
    e.Lifetime = NumberRange.new(0.06, 0.1)
    e.Speed = NumberRange.new(0, 2)
    e.SpreadAngle = Vector2.new(28, 28)
    e.Rate = 0
    e.LightEmission = 1
    e.LightInfluence = 0
    e.Parent = p
    p.Parent = Workspace
    e:Emit(6)
    Debris:AddItem(p, 0.2)
end

-- A small gold sparkle when a coin is collected. Self-bright so it reads as a
-- reward pop; brief and self-cleaning.
function CombatFx.Pickup(position: Vector3)
    local pt = anchor(position + Vector3.new(0, 1, 0))
    local e = Instance.new("ParticleEmitter")
    e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    e.Color = ColorSequence.new(Color3.fromRGB(255, 214, 92), Color3.fromRGB(242, 166, 59))
    e.Transparency = NumberSequence.new(0.05, 1)
    e.Size = NumberSequence.new(0.5, 0.05)
    e.Lifetime = NumberRange.new(0.25, 0.5)
    e.Speed = NumberRange.new(3, 6)
    e.SpreadAngle = Vector2.new(180, 180)
    e.Acceleration = Vector3.new(0, -12, 0)
    e.Rate = 0
    e.LightEmission = 0.6
    e.LightInfluence = 0
    e.Parent = pt
    pt.Parent = Workspace
    e:Emit(12)
    Debris:AddItem(pt, 0.6)
end

-- Becoming the hero: a rising cyan-and-gold flare when a player takes the
-- dropped pistol. A public, loud moment already (gun_pickup), so a bright pop
-- fits; brief and self-cleaning.
function CombatFx.Hero(position: Vector3)
    local pt = anchor(position + Vector3.new(0, 2, 0))
    local e = Instance.new("ParticleEmitter")
    e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    e.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(55, 188, 240)),
        ColorSequenceKeypoint.new(0.6, Color3.fromRGB(255, 214, 92)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 214, 92)),
    })
    e.Transparency = NumberSequence.new(0.05, 1)
    e.Size = NumberSequence.new(0.6, 0.05)
    e.Lifetime = NumberRange.new(0.4, 0.8)
    e.Speed = NumberRange.new(6, 11)
    e.SpreadAngle = Vector2.new(60, 60)
    e.Acceleration = Vector3.new(0, 6, 0)
    e.Rate = 0
    e.LightEmission = 0.6
    e.LightInfluence = 0
    e.Parent = pt
    pt.Parent = Workspace
    e:Emit(26)
    Debris:AddItem(pt, 0.9)
end

return CombatFx
