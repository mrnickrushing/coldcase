--[[
  COLD CASE · lighting. Bright daylight, a warm grade, a little glow on neon.
  Bootstrap runs this on server start, before EventService captures the base
  light levels it restores after Lights Out.

  Never adds an Atmosphere: VisionController draws the vision radius with
  legacy fog, and an Atmosphere disables it. Lighting.Technology cannot be set
  from a script; the place is saved with Future.
]]
local Lighting = game:GetService("Lighting")

local function ensure(className: string, name: string): Instance
    local inst = Lighting:FindFirstChildOfClass(className :: any)
    if not inst then
        inst = Instance.new(className :: any)
        inst.Name = name
        inst.Parent = Lighting
    end
    return inst
end

return function()
    for _, child in Lighting:GetChildren() do
        if child:IsA("Atmosphere") then
            child:Destroy()
        end
    end

    -- Bright and readable, the way the big social-deduction games look: the
    -- drama comes from who is holding the knife, not from squinting.
    -- Lights Out (EventService) drops brightness and ambient from here.
    Lighting.ClockTime = 15
    Lighting.Brightness = 2.1
    Lighting.Ambient = Color3.fromRGB(96, 100, 110)
    Lighting.OutdoorAmbient = Color3.fromRGB(128, 134, 148)
    Lighting.EnvironmentDiffuseScale = 0.35
    Lighting.EnvironmentSpecularScale = 0.8
    Lighting.GlobalShadows = true
    Lighting.ExposureCompensation = -0.1

    local sky = ensure("Sky", "DaySky") :: Sky
    sky.StarCount = 0
    sky.SunAngularSize = 14

    local grade = ensure("ColorCorrectionEffect", "Grade") :: ColorCorrectionEffect
    grade.Saturation = 0.18
    grade.Contrast = 0.1
    grade.TintColor = Color3.fromRGB(255, 252, 245)

    local bloom = ensure("BloomEffect", "Glow") :: BloomEffect
    bloom.Intensity = 0.3
    bloom.Size = 24
    bloom.Threshold = 1.8
end
